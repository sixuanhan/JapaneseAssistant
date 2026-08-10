//
//  Word.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//
//  Note: the property names `Phonetic`, `Kanji`, `English` are PascalCase
//  for legacy compatibility with the persisted schema — they double as
//  the CodingKeys. New properties should follow lowerCamelCase.
//

import Foundation

struct Word: Codable, Identifiable, Hashable {
    var id = UUID()
    var Phonetic: String
    var Kanji: String
    var English: String
    var example: String
    var nextDueDate: Date
    /// Group this word belongs to. `nil` means "not in any group".
    /// `Word.vocabGroupId` is the source of truth for group membership;
    /// `VocabGroup.wordMembers` is derived from it.
    var vocabGroupId: UUID?

    /// UX-facing label. Prefers Kanji, then Phonetic, then English —
    /// this fallback order is a stable contract that `ListView`,
    /// `EditWordView`, and the AI prompt builder all rely on.
    var displayText: String {
        let trimmedKanji = Kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKanji.isEmpty {
            return trimmedKanji
        }
        let trimmedPhonetic = Phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPhonetic.isEmpty {
            return trimmedPhonetic
        }
        return English
    }

    init(
        id: UUID = UUID(),
        Phonetic: String,
        Kanji: String,
        English: String,
        example: String,
        nextDueDate: Date,
        vocabGroupId: UUID? = nil
    ) {
        self.id = id
        self.Phonetic = Phonetic
        self.Kanji = Kanji
        self.English = English
        self.example = example
        self.nextDueDate = nextDueDate
        self.vocabGroupId = vocabGroupId
    }

    enum CodingKeys: String, CodingKey {
        case id, Phonetic, Kanji, English, example, nextDueDate, vocabGroupId
    }

    // Custom decoder tolerates old blobs written before `vocabGroupId`
    // existed and shields against partially-corrupt documents by
    // falling back to safe defaults. Encoding uses the compiler-
    // synthesised path, which already emits `encodeIfPresent` for the
    // Optional `vocabGroupId`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        Phonetic = try container.decodeIfPresent(String.self, forKey: .Phonetic) ?? ""
        Kanji = try container.decodeIfPresent(String.self, forKey: .Kanji) ?? ""
        English = try container.decodeIfPresent(String.self, forKey: .English) ?? ""
        example = try container.decodeIfPresent(String.self, forKey: .example) ?? ""
        nextDueDate = try container.decodeIfPresent(Date.self, forKey: .nextDueDate) ?? Date()
        vocabGroupId = try container.decodeIfPresent(UUID.self, forKey: .vocabGroupId)
    }

    // Identity is defined by `id` alone so `Set<Word>` and
    // `wordBank.contains(where:)` behave the way callers expect.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Word, rhs: Word) -> Bool {
        lhs.id == rhs.id
    }
}
