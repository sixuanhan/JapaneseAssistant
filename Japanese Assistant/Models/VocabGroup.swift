//
//  VocabGroup.swift
//  Japanese Assistant
//
//  A user-curated group of related vocabulary words (e.g. synonyms,
//  homophones, easily-confused pairs).
//
//  Data-model contract:
//  - `Word.vocabGroupId` is the source of truth for group membership.
//  - `VocabGroup.wordMembers` is a materialised view kept in sync with
//    `WordBankManager` by `VocabGroupManager`.
//

import Foundation

struct VocabGroup: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Materialised member list. Callers should treat `Word.vocabGroupId`
    /// as authoritative; `VocabGroupManager` rebuilds this list from the
    /// word bank whenever the group is saved.
    var wordMembers: [Word]
    /// AI-generated differentiation note explaining how the members relate
    /// or differ. Empty until the user requests a note in the editor.
    var vocabGroupNote: String = ""

    /// Persisted key is retained as `WordMembers` (PascalCase) so
    /// existing Firestore documents and UserDefaults blobs continue to
    /// decode. The Swift property is `wordMembers` per Swift naming
    /// conventions.
    enum CodingKeys: String, CodingKey {
        case id
        case wordMembers = "WordMembers"
        case vocabGroupNote
    }

    init(id: UUID = UUID(), wordMembers: [Word], vocabGroupNote: String = "") {
        self.id = id
        self.wordMembers = wordMembers
        self.vocabGroupNote = vocabGroupNote
    }

    // Identity is defined by `id` alone so a `Set<VocabGroup>` or
    // `wordBank.contains(where:)` lookup by id behaves as callers expect.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VocabGroup, rhs: VocabGroup) -> Bool {
        lhs.id == rhs.id
    }
}
