//
//  LocalDataStore.swift
//  Japanese Assistant
//
//  Per-user local persistence layer backing the app's offline-first UX.
//  All UI-facing reads and writes go through here (via WordBankManager,
//  KnowledgeManager, VocabGroupManager) so the app remains fully usable
//  with no network, and cloud sync is layered on top by AuthViewModel.
//
//  Passing `uid: nil` accesses the "anonymous" blob, which serves two
//  overlapping purposes depending on the collection:
//
//  - For `wordBank` / `knowledgeCards`, `uid: nil` also holds the legacy
//    pre-Firebase blob (the keys pre-date the migration).
//  - For `sampleSentences` / `vocabGroups`, `uid: nil` is the current
//    signed-out user's cache.
//
//  `AuthViewModel.migrateLegacyLocalDataIfNeeded` folds all four
//  `uid: nil` blobs into the per-uid cache on first sign-in so no
//  anonymous data is ever orphaned regardless of category.
//

import Foundation

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

    private static func sampleSentencesKey(uid: String?) -> String {
        "sample_sentences_\(uid ?? "anonymous")"
    }

    private static func vocabGroupsKey(uid: String?) -> String {
        "vocab_groups_\(uid ?? "anonymous")"
    }

    private static func pendingKey(uid: String) -> String { "hasPendingSync_\(uid)" }
    private static func migratedKey(uid: String) -> String { "didMigrateLegacy_\(uid)" }
    private static func lastLocalUpdateKey(uid: String) -> String { "lastLocalUpdate_\(uid)" }

    // MARK: - Word bank

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

    // MARK: - Knowledge cards

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

    // MARK: - Sample sentences

    static func loadSampleSentences(uid: String?) -> [Knowledge] {
        guard let data = UserDefaults.standard.data(forKey: sampleSentencesKey(uid: uid)),
              let decoded = try? JSONDecoder().decode([Knowledge].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveSampleSentences(_ cards: [Knowledge], uid: String?) {
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: sampleSentencesKey(uid: uid))
        }
    }

    // MARK: - Vocab groups

    static func loadVocabGroups(uid: String?) -> [VocabGroup] {
        guard let data = UserDefaults.standard.data(forKey: vocabGroupsKey(uid: uid)),
              let decoded = try? JSONDecoder().decode([VocabGroup].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveVocabGroups(_ vocabGroups: [VocabGroup], uid: String?) {
        if let encoded = try? JSONEncoder().encode(vocabGroups) {
            UserDefaults.standard.set(encoded, forKey: vocabGroupsKey(uid: uid))
        }
    }

    // MARK: - Sync flags

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

    /// Timestamp of the most recent local mutation for the given user.
    /// `nil` means the local cache has never been written on this device.
    /// Used by `AuthViewModel.mergeLocalAndCloud` to decide which side to
    /// trust when reconciling local and cloud snapshots.
    static func loadLastLocalUpdate(uid: String) -> Date? {
        UserDefaults.standard.object(forKey: lastLocalUpdateKey(uid: uid)) as? Date
    }

    static func saveLastLocalUpdate(_ date: Date, uid: String) {
        UserDefaults.standard.set(date, forKey: lastLocalUpdateKey(uid: uid))
    }

    /// Removes every per-uid key for the given user. Called from
    /// `AuthViewModel.deleteAccount` so that account deletion truly
    /// removes all of the user's on-device data.
    static func clearAll(uid: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: wordBankKey(uid: uid))
        defaults.removeObject(forKey: knowledgeKey(uid: uid))
        defaults.removeObject(forKey: sampleSentencesKey(uid: uid))
        defaults.removeObject(forKey: vocabGroupsKey(uid: uid))
        defaults.removeObject(forKey: pendingKey(uid: uid))
        defaults.removeObject(forKey: migratedKey(uid: uid))
        defaults.removeObject(forKey: lastLocalUpdateKey(uid: uid))
    }
}
