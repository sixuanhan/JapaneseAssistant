
//
//  VocabGroupManager.swift
//  Japanese Assistant
//

import Foundation

/// Facade over the signed-in user's vocab-group collection.
///
/// `Word.vocabGroupId` is the source of truth for group membership.
/// `VocabGroup.wordMembers` is a materialised view that this manager
/// keeps in sync with the passed `wordBank`.
class VocabGroupManager {
    static let shared = VocabGroupManager()

    @MainActor
    func loadVocabGroups() -> [VocabGroup] {
        let uid = AuthViewModel.shared?.userSession?.uid
        return LocalDataStore.loadVocabGroups(uid: uid)
    }

    @MainActor
    func saveVocabGroups(_ vocabGroups: [VocabGroup]) {
        if let auth = AuthViewModel.shared, auth.userSession != nil {
            auth.setVocabGroups(vocabGroups)
        } else {
            LocalDataStore.saveVocabGroups(vocabGroups, uid: nil)
        }
    }

    /// Inserts or updates `group`, then rebuilds `wordMembers` on every
    /// *other* group from `wordBank` and prunes any that end up empty.
    ///
    /// The passed `group`'s `wordMembers` and `vocabGroupNote` are kept
    /// verbatim — callers are responsible for constructing the group with
    /// its intended members before calling. (Sibling groups are rebuilt
    /// from `wordBank` so ripple effects from moving a word between
    /// groups are handled in one place.)
    @MainActor
    func saveGroup(_ group: VocabGroup, with wordBank: [Word]) {
        var groups = loadVocabGroups()
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }

        groups = groups.compactMap { existing in
            if existing.id == group.id { return existing }
            let members = wordBank.filter { $0.vocabGroupId == existing.id }
            guard !members.isEmpty else { return nil }
            return VocabGroup(id: existing.id, wordMembers: members, vocabGroupNote: existing.vocabGroupNote)
        }

        saveVocabGroups(groups)
    }

    /// Rebuilds every group's `wordMembers` from the passed `wordBank`
    /// and drops groups that no longer have any members. Intended as a
    /// reconciliation hook after a word's `vocabGroupId` changes or a
    /// word is deleted.
    @MainActor
    func pruneEmptyGroups(with wordBank: [Word]) {
        let groups = loadVocabGroups().compactMap { existing -> VocabGroup? in
            let members = wordBank.filter { $0.vocabGroupId == existing.id }
            guard !members.isEmpty else { return nil }
            return VocabGroup(id: existing.id, wordMembers: members, vocabGroupNote: existing.vocabGroupNote)
        }
        saveVocabGroups(groups)
    }
}
