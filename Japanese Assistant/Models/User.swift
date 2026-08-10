//
//  User.swift
//  Japanese Assistant
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    var id: String
    var username: String
    var email: String
    var wordBank: [Word]
    var vocabGroups: [VocabGroup] = []
    var knowledgeCards: [Knowledge]
    var sampleSentences: [Knowledge] = []
    /// Time of the most recent local mutation. `nil` means the local
    /// cache has never been written on this device; used by the sync
    /// merge policy to decide which side to trust.
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, email, wordBank, vocabGroups, knowledgeCards, sampleSentences, updatedAt
    }

    init(
        id: String,
        username: String,
        email: String,
        wordBank: [Word],
        vocabGroups: [VocabGroup] = [],
        knowledgeCards: [Knowledge],
        sampleSentences: [Knowledge] = [],
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.wordBank = wordBank
        self.vocabGroups = vocabGroups
        self.knowledgeCards = knowledgeCards
        self.sampleSentences = sampleSentences
        self.updatedAt = updatedAt
    }

    // Custom decoder tolerates cloud documents written before the
    // `vocabGroups` / `sampleSentences` / `updatedAt` fields existed.
    // The compiler-synthesized `init(from:)` would use `decode(_:forKey:)`
    // for the non-Optional collections and throw `keyNotFound` on legacy
    // docs, which callers currently only log and swallow — silently
    // stranding every existing user on their local cache.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        wordBank = try container.decodeIfPresent([Word].self, forKey: .wordBank) ?? []
        vocabGroups = try container.decodeIfPresent([VocabGroup].self, forKey: .vocabGroups) ?? []
        knowledgeCards = try container.decodeIfPresent([Knowledge].self, forKey: .knowledgeCards) ?? []
        sampleSentences = try container.decodeIfPresent([Knowledge].self, forKey: .sampleSentences) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    mutating func updateVocabGroup(_ group: VocabGroup) {
        if let index = vocabGroups.firstIndex(where: { $0.id == group.id }) {
            vocabGroups[index] = group
        } else {
            vocabGroups.append(group)
        }
    }

    mutating func removeVocabGroup(id: UUID) {
        vocabGroups.removeAll { $0.id == id }
    }
}
