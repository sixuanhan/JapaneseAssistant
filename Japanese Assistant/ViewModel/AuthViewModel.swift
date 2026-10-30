//
//  AuthViewModel.swift
//  Japanese Assistant
//
//  Email/password auth backed by Firebase Auth, plus an offline-first
//  sync layer over a per-user Firestore document.
//
//  Design:
//  - `LocalDataStore` (UserDefaults) is the source of truth for the UI.
//    Reads and writes through `WordBankManager` / `KnowledgeManager` /
//    `VocabGroupManager` always hit it first, so the app is fully usable
//    with no network.
//  - Every write also fires a Firestore `setData` call. The Firestore
//    SDK transparently queues writes when offline and replays them when
//    connectivity returns.
//  - A per-uid "pending sync" flag tracks whether the local cache has
//    changes that have not yet been confirmed by the server. On app
//    launch and every foreground transition, `syncWithCloud()` uses the
//    flag to decide whether to push local → cloud (preserving unsynced
//    offline edits) or pull cloud → local (adopting changes made from
//    other devices).
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import Combine

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    /// Shared instance so the legacy singleton managers
    /// (`WordBankManager` / `KnowledgeManager` / `VocabGroupManager`)
    /// can talk to the current signed-in user without taking an
    /// environment object.
    static weak var shared: AuthViewModel?

    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?

    @Published var alertMessage: AlertMessage?
    @Published var loginError: String?

    init() {
        self.userSession = Auth.auth().currentUser
        AuthViewModel.shared = self

        Task { await syncWithCloud() }
    }

    // MARK: - Sign In / Up / Out

    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            self.loginError = nil
            await migrateLegacyLocalDataIfNeeded(uid: result.user.uid)
            await syncWithCloud()
        } catch let error as NSError {
            print("DEBUG: Firebase Error Code: \(error.code)")
            print("DEBUG: Error Message: \(error.localizedDescription)")

            switch error.code {
            case 17004, 17008, 17009:
                self.loginError = "Incorrect email or password."
            case 17010:
                self.loginError = "Too many attempts. Please try again later."
            case 17020:
                self.loginError = "Network unavailable. Please check your connection."
            default:
                self.loginError = "An unexpected error occurred. Please try again later."
            }
        }
    }

    func createUser(withEmail email: String, password: String, fullname: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user

            // Seed the new user document with whatever the user already
            // had stored locally so anonymous-era data isn't lost.
            let user = User(
                id: result.user.uid,
                username: fullname,
                email: email,
                wordBank: LocalDataStore.loadWordBank(uid: nil),
                vocabGroups: LocalDataStore.loadVocabGroups(uid: nil),
                knowledgeCards: LocalDataStore.loadKnowledgeCards(uid: nil),
                sampleSentences: LocalDataStore.loadSampleSentences(uid: nil),
                updatedAt: Date()
            )
            self.currentUser = user

            // Persist into the per-uid local cache so subsequent offline
            // launches see the data even before the server round-trip.
            persistLocally(user: user, uid: user.id, timestamp: user.updatedAt ?? Date())
            LocalDataStore.setPendingSync(true, uid: user.id)
            LocalDataStore.markLegacyMigrated(uid: user.id)

            queueCloudPush(uid: user.id)
        } catch let error as NSError {
            if let authError = AuthErrorCode(rawValue: error._code) {
                switch authError {
                case .emailAlreadyInUse:
                    throw AuthError.emailAlreadyInUse
                case .invalidEmail:
                    throw AuthError.invalidEmail
                case .networkError:
                    throw AuthError.unknown("Network unavailable. Please check your connection.")
                default:
                    throw AuthError.unknown(error.localizedDescription)
                }
            } else {
                throw AuthError.unknown(error.localizedDescription)
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("DEBUG: Failed to sign out with error \(error.localizedDescription)")
        }
    }

    // MARK: - Account Management

    func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            print("DEBUG: No user is currently signed in.")
            return
        }

        let alert = UIAlertController(
            title: "Re-authenticate",
            message: "Please enter your password to confirm account deletion.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        let confirmAction = UIAlertAction(title: "Confirm", style: .destructive) { [weak alert] _ in
            guard let password = alert?.textFields?.first?.text, !password.isEmpty,
                  let email = user.email else {
                print("DEBUG: Password cannot be empty.")
                return
            }

            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            user.reauthenticate(with: credential) { _, error in
                if let error = error {
                    print("DEBUG: Failed to reauthenticate user: \(error.localizedDescription)")
                    return
                }

                Task { @MainActor in
                    do {
                        let uid = user.uid
                        self.userSession = nil
                        self.currentUser = nil
                        LocalDataStore.clearAll(uid: uid)

                        try await Firestore.firestore().collection("users").document(uid).delete()
                        try await user.delete()
                        print("DEBUG: Account deleted successfully.")
                    } catch {
                        print("DEBUG: Failed to delete account with error \(error.localizedDescription)")
                        self.signOut()
                    }
                }
            }
        }
        alert.addAction(confirmAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            print("DEBUG: Account deletion canceled.")
        }
        cancelAction.setValue(UIColor.blue, forKey: "titleTextColor")
        alert.addAction(cancelAction)

        Application_utility.rootViewController.present(alert, animated: true, completion: nil)
    }

    func updatePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."])
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)

        do {
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
        } catch let error as NSError {
            print("DEBUG: Failed to update password: \(error.localizedDescription)")
            if error.code == AuthErrorCode.wrongPassword.rawValue {
                throw NSError(domain: "", code: AuthErrorCode.wrongPassword.rawValue,
                              userInfo: [NSLocalizedDescriptionKey: "The current password you entered is incorrect."])
            } else {
                throw error
            }
        }
    }

    // MARK: - Data Mutators
    //
    // Called by WordBankManager / KnowledgeManager / VocabGroupManager
    // whenever a UI mutation lands. Each one funnels through
    // `markUserModified` so the "stamp updatedAt → save every collection
    // locally → mark pending → queue cloud push" sequence lives in one
    // place. Silent no-ops when signed out — anonymous edits go directly
    // to `LocalDataStore(uid: nil)` through the manager facades and get
    // migrated on the next sign-in.

    func setWordBank(_ wordBank: [Word]) {
        guard let uid = userSession?.uid else { return }
        markUserModified(uid: uid) { $0.wordBank = wordBank }
    }

    func setVocabGroups(_ vocabGroups: [VocabGroup]) {
        guard let uid = userSession?.uid else { return }
        markUserModified(uid: uid) { $0.vocabGroups = vocabGroups }
    }

    func updateVocabGroup(_ group: VocabGroup) {
        guard let uid = userSession?.uid else { return }
        markUserModified(uid: uid) { $0.updateVocabGroup(group) }
    }

    func removeVocabGroup(id: UUID) {
        guard let uid = userSession?.uid else { return }
        markUserModified(uid: uid) { $0.removeVocabGroup(id: id) }
    }

    func setKnowledgeCards(_ cards: [Knowledge]) {
        guard let uid = userSession?.uid else { return }
        markUserModified(uid: uid) { $0.knowledgeCards = cards }
    }

    func setSampleSentences(_ cards: [Knowledge]) {
        guard let uid = userSession?.uid else { return }
        markUserModified(uid: uid) { $0.sampleSentences = cards }
    }

    /// Applies `mutate` to `currentUser` (hydrating from the local cache
    /// if needed), stamps `updatedAt = now`, writes every collection to
    /// the per-uid `LocalDataStore` synchronously, flips the pending-sync
    /// flag, and queues a Firestore push.
    ///
    /// Persisting every collection on each mutation keeps the on-disk
    /// snapshot consistent with `currentUser` at all times — which is
    /// the invariant `pullCloudToLocal` relies on when it reads the
    /// local baseline for merging.
    private func markUserModified(uid: String, mutate: (inout User) -> Void) {
        var user = currentUser ?? hydrateFromLocalCache(uid: uid)
        mutate(&user)
        let now = Date()
        user.updatedAt = now
        currentUser = user
        persistLocally(user: user, uid: uid, timestamp: now)
        LocalDataStore.setPendingSync(true, uid: uid)
        queueCloudPush(uid: uid)
    }

    private func persistLocally(user: User, uid: String, timestamp: Date) {
        LocalDataStore.saveWordBank(user.wordBank, uid: uid)
        LocalDataStore.saveVocabGroups(user.vocabGroups, uid: uid)
        LocalDataStore.saveKnowledgeCards(user.knowledgeCards, uid: uid)
        LocalDataStore.saveSampleSentences(user.sampleSentences, uid: uid)
        LocalDataStore.saveLastLocalUpdate(timestamp, uid: uid)
    }

    private func hydrateFromLocalCache(uid: String) -> User {
        User(
            id: uid,
            username: Auth.auth().currentUser?.displayName ?? currentUser?.username ?? "",
            email: Auth.auth().currentUser?.email ?? currentUser?.email ?? "",
            wordBank: LocalDataStore.loadWordBank(uid: uid),
            vocabGroups: LocalDataStore.loadVocabGroups(uid: uid),
            knowledgeCards: LocalDataStore.loadKnowledgeCards(uid: uid),
            sampleSentences: LocalDataStore.loadSampleSentences(uid: uid),
            updatedAt: LocalDataStore.loadLastLocalUpdate(uid: uid)
        )
    }

    // MARK: - Sync

    /// Called on app launch and whenever the app returns to the
    /// foreground. Decides whether to push local → cloud or pull cloud
    /// → local based on the pending-sync flag, so unsynced offline edits
    /// are never silently overwritten by a stale cloud snapshot.
    func syncWithCloud() async {
        guard let uid = userSession?.uid else { return }

        // Populate `currentUser` from the local cache so the UI has
        // something to show immediately, even if the cloud round-trip
        // fails or takes a while.
        if currentUser == nil {
            currentUser = hydrateFromLocalCache(uid: uid)
        }

        if LocalDataStore.hasPendingSync(uid: uid) {
            await push(uid: uid)
        } else {
            await pullCloudToLocal(uid: uid)
        }
    }

    /// Fire-and-forget wrapper around `push(uid:)` used by mutators.
    /// The Firestore SDK queues writes when offline and replays them
    /// on reconnect, so this never blocks the caller.
    private func queueCloudPush(uid: String) {
        Task { await push(uid: uid) }
    }

    /// Writes `currentUser` to Firestore. Clears the pending-sync flag
    /// only on success — offline / transient failures leave the flag
    /// set so the next `syncWithCloud()` will retry.
    private func push(uid: String) async {
        guard let user = currentUser else { return }
        do {
            try Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(from: user)
            LocalDataStore.setPendingSync(false, uid: uid)
        } catch {
            print("DEBUG: Cloud write failed (will retry on next sync): \(error.localizedDescription)")
        }
    }

    private func pullCloudToLocal(uid: String) async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()
            guard snapshot.data() != nil else {
                print("DEBUG: No cloud document for uid \(uid).")
                return
            }
            let cloudUser = try snapshot.data(as: User.self)
            let localUser = hydrateFromLocalCache(uid: uid)
            let mergedUser = mergeLocalAndCloud(localUser: localUser, cloudUser: cloudUser)
            self.currentUser = mergedUser
            LocalDataStore.saveWordBank(mergedUser.wordBank, uid: uid)
            LocalDataStore.saveVocabGroups(mergedUser.vocabGroups, uid: uid)
            LocalDataStore.saveKnowledgeCards(mergedUser.knowledgeCards, uid: uid)
            LocalDataStore.saveSampleSentences(mergedUser.sampleSentences, uid: uid)
            // Preserve the previous local timestamp when the merged user
            // has none — nil-clobbering would erase useful sync-state
            // information and cause the next merge to behave as though
            // this device had never written.
            if let updatedAt = mergedUser.updatedAt {
                LocalDataStore.saveLastLocalUpdate(updatedAt, uid: uid)
            }
        } catch {
            // Offline or transient failure — UI keeps using the local cache.
            print("DEBUG: pullCloudToLocal failed: \(error.localizedDescription)")
        }
    }

    /// Whole-document last-writer-wins merge policy.
    ///
    /// - When both sides have an `updatedAt`, the newer document wins in
    ///   its entirety. This means a burst of edits on one device while
    ///   another device was making unrelated edits can drop the loser's
    ///   changes — an inherent limitation of the current design.
    /// - When only local has a timestamp, keep local (we assume the
    ///   local device saw the cloud earlier and moved on).
    /// - When only cloud has a timestamp, keep cloud.
    /// - When neither has a timestamp, fall back to whichever side has
    ///   any data. A first-run device with no local data should adopt
    ///   the cloud snapshot; otherwise keep local. "Empty" means every
    ///   user-owned collection is empty.
    private func mergeLocalAndCloud(localUser: User, cloudUser: User) -> User {
        switch (localUser.updatedAt, cloudUser.updatedAt) {
        case let (local?, cloud?):
            return cloud > local ? cloudUser : localUser
        case (_?, nil):
            return localUser
        case (nil, _?):
            return cloudUser
        case (nil, nil):
            return isEmpty(cloudUser) ? localUser : cloudUser
        }
    }

    private func isEmpty(_ user: User) -> Bool {
        return user.wordBank.isEmpty
            && user.vocabGroups.isEmpty
            && user.knowledgeCards.isEmpty
            && user.sampleSentences.isEmpty
    }

    // MARK: - Legacy Migration (pre-Firebase / anonymous UserDefaults blob)

    /// One-shot copy of any data stored under the legacy / anonymous
    /// UserDefaults keys into the per-uid cache. Merged with whatever is
    /// already in the per-uid cache; ids that don't already exist are
    /// appended (union semantics; per-uid data wins on id conflict).
    ///
    /// Covers all four user-owned collections so anonymous edits made
    /// before sign-in are never orphaned.
    private func migrateLegacyLocalDataIfNeeded(uid: String) async {
        guard !LocalDataStore.hasMigratedLegacy(uid: uid) else { return }

        let legacyWords = LocalDataStore.loadWordBank(uid: nil)
        let legacyKnowledge = LocalDataStore.loadKnowledgeCards(uid: nil)
        let legacySampleSentences = LocalDataStore.loadSampleSentences(uid: nil)
        let legacyVocabGroups = LocalDataStore.loadVocabGroups(uid: nil)

        let anythingToMigrate = !legacyWords.isEmpty
            || !legacyKnowledge.isEmpty
            || !legacySampleSentences.isEmpty
            || !legacyVocabGroups.isEmpty
        guard anythingToMigrate else {
            LocalDataStore.markLegacyMigrated(uid: uid)
            return
        }

        var perUserWords = LocalDataStore.loadWordBank(uid: uid)
        let existingWordIds = Set(perUserWords.map { $0.id })
        perUserWords.append(contentsOf: legacyWords.filter { !existingWordIds.contains($0.id) })
        LocalDataStore.saveWordBank(perUserWords, uid: uid)

        var perUserKnowledge = LocalDataStore.loadKnowledgeCards(uid: uid)
        let existingKnowledgeIds = Set(perUserKnowledge.map { $0.id })
        perUserKnowledge.append(contentsOf: legacyKnowledge.filter { !existingKnowledgeIds.contains($0.id) })
        LocalDataStore.saveKnowledgeCards(perUserKnowledge, uid: uid)

        var perUserSampleSentences = LocalDataStore.loadSampleSentences(uid: uid)
        let existingSampleIds = Set(perUserSampleSentences.map { $0.id })
        perUserSampleSentences.append(contentsOf: legacySampleSentences.filter { !existingSampleIds.contains($0.id) })
        LocalDataStore.saveSampleSentences(perUserSampleSentences, uid: uid)

        var perUserVocabGroups = LocalDataStore.loadVocabGroups(uid: uid)
        let existingVocabGroupIds = Set(perUserVocabGroups.map { $0.id })
        perUserVocabGroups.append(contentsOf: legacyVocabGroups.filter { !existingVocabGroupIds.contains($0.id) })
        LocalDataStore.saveVocabGroups(perUserVocabGroups, uid: uid)

        LocalDataStore.setPendingSync(true, uid: uid)
        LocalDataStore.markLegacyMigrated(uid: uid)
    }
}

struct AlertMessage: Identifiable {
    let id = UUID()
    let message: String
}

enum AuthError: LocalizedError {
    case emailAlreadyInUse
    case invalidEmail
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .emailAlreadyInUse:
            return "This email is already in use."
        case .invalidEmail:
            return "Invalid email format. Please enter a valid email."
        case .unknown(let message):
            return message
        }
    }
}
