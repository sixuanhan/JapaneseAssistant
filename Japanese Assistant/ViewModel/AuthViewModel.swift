//
//  AuthViewModel.swift
//  Japanese Assistant
//
//  Email/password auth backed by Firebase Auth, plus an offline-first
//  sync layer over a per-user Firestore document.
//
//  Design:
//  - LocalDataStore (UserDefaults) is the single source of truth for the
//    UI. Reads and writes through WordBankManager / KnowledgeManager always
//    hit it first, so the app is fully usable with no network.
//  - Every write also fires a Firestore `setData` call. The Firestore SDK
//    transparently queues writes when offline and replays them when
//    connectivity returns.
//  - A per-uid "pending sync" flag tracks whether the local cache has
//    changes that have not yet been confirmed by the server. The sync
//    routine uses that flag to decide whether to push local → cloud or
//    pull cloud → local on app launch / foreground.
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
    /// (WordBankManager / KnowledgeManager) can talk to the current
    /// signed-in user without taking an environment object.
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

            // Seed the new user document with whatever the user already had
            // stored locally so anonymous-era data isn't lost on first sign up.
            let localWordBank = LocalDataStore.loadWordBank(uid: nil)
            let localKnowledge = LocalDataStore.loadKnowledgeCards(uid: nil)

            let user = User(
                id: result.user.uid,
                username: fullname,
                email: email,
                wordBank: localWordBank,
                knowledgeCards: localKnowledge
            )
            self.currentUser = user

            // Persist into the per-uid local cache so subsequent offline
            // launches see the data even before the server round-trip.
            LocalDataStore.saveWordBank(localWordBank, uid: user.id)
            LocalDataStore.saveKnowledgeCards(localKnowledge, uid: user.id)
            LocalDataStore.setPendingSync(true, uid: user.id)

            // Fire-and-forget the cloud write; Firestore queues offline.
            pushCurrentUserToCloud(uid: user.id)
            LocalDataStore.markLegacyMigrated(uid: user.id)
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

    // MARK: - Data Mutators (called by WordBankManager / KnowledgeManager)

    /// Records a word-bank change. The local cache is updated synchronously,
    /// a pending-sync flag is set, and a Firestore write is queued. If the
    /// device is offline the write sits in Firestore's outbox and replays
    /// automatically once connectivity returns.
    func setWordBank(_ wordBank: [Word]) {
        guard let uid = userSession?.uid else { return }
        currentUser?.wordBank = wordBank
        LocalDataStore.saveWordBank(wordBank, uid: uid)
        LocalDataStore.setPendingSync(true, uid: uid)
        pushCurrentUserToCloud(uid: uid)
    }

    func setKnowledgeCards(_ cards: [Knowledge]) {
        guard let uid = userSession?.uid else { return }
        currentUser?.knowledgeCards = cards
        LocalDataStore.saveKnowledgeCards(cards, uid: uid)
        LocalDataStore.setPendingSync(true, uid: uid)
        pushCurrentUserToCloud(uid: uid)
    }

    // MARK: - Sync

    /// Called on app launch and whenever the app returns to the foreground.
    /// Decides whether to push local → cloud or pull cloud → local based on
    /// the pending-sync flag, so unsynced offline edits are never silently
    /// overwritten by a stale cloud snapshot.
    func syncWithCloud() async {
        guard let uid = userSession?.uid else { return }

        // First populate currentUser from the local cache so the UI has
        // something to show immediately even if cloud is unreachable.
        if currentUser == nil {
            currentUser = User(
                id: uid,
                username: Auth.auth().currentUser?.displayName ?? "",
                email: Auth.auth().currentUser?.email ?? "",
                wordBank: LocalDataStore.loadWordBank(uid: uid),
                knowledgeCards: LocalDataStore.loadKnowledgeCards(uid: uid)
            )
        }

        if LocalDataStore.hasPendingSync(uid: uid) {
            await pushLocalToCloud(uid: uid)
        } else {
            await pullCloudToLocal(uid: uid)
        }
    }

    private func pushCurrentUserToCloud(uid: String) {
        guard let user = currentUser else { return }
        Task {
            do {
                try Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .setData(from: user)
                // setData completes when the write reaches the server, so
                // it's safe to clear the pending flag here.
                LocalDataStore.setPendingSync(false, uid: uid)
            } catch {
                print("DEBUG: Cloud write failed (will retry on next sync): \(error.localizedDescription)")
            }
        }
    }

    private func pushLocalToCloud(uid: String) async {
        guard let user = currentUser else { return }
        do {
            try Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(from: user)
            LocalDataStore.setPendingSync(false, uid: uid)
        } catch {
            print("DEBUG: pushLocalToCloud failed (still offline?): \(error.localizedDescription)")
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
            self.currentUser = cloudUser
            LocalDataStore.saveWordBank(cloudUser.wordBank, uid: uid)
            LocalDataStore.saveKnowledgeCards(cloudUser.knowledgeCards, uid: uid)
        } catch {
            // Offline or transient failure — UI keeps using the local cache.
            print("DEBUG: pullCloudToLocal failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Legacy Migration (pre-Firebase UserDefaults blob)

    /// One-shot copy of any data stored under the legacy global keys
    /// (`WordBank`, `KnowledgeCards`) into the per-uid cache. Merged with
    /// whatever is already in the per-uid cache; legacy ids that don't
    /// already exist are appended.
    private func migrateLegacyLocalDataIfNeeded(uid: String) async {
        guard !LocalDataStore.hasMigratedLegacy(uid: uid) else { return }

        let legacyWords = LocalDataStore.loadWordBank(uid: nil)
        let legacyKnowledge = LocalDataStore.loadKnowledgeCards(uid: nil)
        guard !legacyWords.isEmpty || !legacyKnowledge.isEmpty else {
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

// MARK: - LocalDataStore
//
// All of the app's user-facing reads are served from here so the app works
// fully offline. Pass `uid: nil` to access the legacy global blob that
// pre-dated the Firebase migration; pass a real uid for everything else.

enum LocalDataStore {
    private static let legacyWordBankKey = "WordBank"
    private static let legacyKnowledgeKey = "KnowledgeCards"

    private static func wordBankKey(uid: String?) -> String {
        guard let uid = uid else { return legacyWordBankKey }
        return "WordBank_\(uid)"
    }
    private static func knowledgeKey(uid: String?) -> String {
        guard let uid = uid else { return legacyKnowledgeKey }
        return "KnowledgeCards_\(uid)"
    }
    private static func pendingKey(uid: String) -> String { "hasPendingSync_\(uid)" }
    private static func migratedKey(uid: String) -> String { "didMigrateLegacy_\(uid)" }

    // MARK: Word bank

    static func loadWordBank(uid: String?) -> [Word] {
        guard let data = UserDefaults.standard.data(forKey: wordBankKey(uid: uid)),
              let decoded = try? JSONDecoder().decode([Word].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveWordBank(_ wordBank: [Word], uid: String?) {
        if let encoded = try? JSONEncoder().encode(wordBank) {
            UserDefaults.standard.set(encoded, forKey: wordBankKey(uid: uid))
        }
    }

    // MARK: Knowledge cards

    static func loadKnowledgeCards(uid: String?) -> [Knowledge] {
        guard let data = UserDefaults.standard.data(forKey: knowledgeKey(uid: uid)),
              let decoded = try? JSONDecoder().decode([Knowledge].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveKnowledgeCards(_ cards: [Knowledge], uid: String?) {
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: knowledgeKey(uid: uid))
        }
    }

    // MARK: Sync flags

    static func hasPendingSync(uid: String) -> Bool {
        UserDefaults.standard.bool(forKey: pendingKey(uid: uid))
    }

    static func setPendingSync(_ pending: Bool, uid: String) {
        UserDefaults.standard.set(pending, forKey: pendingKey(uid: uid))
    }

    static func hasMigratedLegacy(uid: String) -> Bool {
        UserDefaults.standard.bool(forKey: migratedKey(uid: uid))
    }

    static func markLegacyMigrated(uid: String) {
        UserDefaults.standard.set(true, forKey: migratedKey(uid: uid))
    }

    static func clearAll(uid: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: wordBankKey(uid: uid))
        defaults.removeObject(forKey: knowledgeKey(uid: uid))
        defaults.removeObject(forKey: pendingKey(uid: uid))
        defaults.removeObject(forKey: migratedKey(uid: uid))
    }
}
