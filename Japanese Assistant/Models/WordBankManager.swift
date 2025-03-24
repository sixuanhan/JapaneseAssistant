//
//  WordBankManager.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import Foundation

class WordBankManager {
    static let shared = WordBankManager()

    private let wordBankKey = "WordBank"

    // Load the word bank from UserDefaults
    func loadWordBank() -> [Word] {
        if let data = UserDefaults.standard.data(forKey: wordBankKey),
           let decoded = try? JSONDecoder().decode([Word].self, from: data) {
            return decoded
        }
        return []
    }

    // Save the word bank to UserDefaults
    func saveWordBank(_ wordBank: [Word]) {
        if let encoded = try? JSONEncoder().encode(wordBank) {
            UserDefaults.standard.set(encoded, forKey: wordBankKey)
        }
    }

    func saveUpdatedWordToWordBank(word: Word) {
        var wordBank = loadWordBank()

        // Find the index of the word to update
        if let index = wordBank.firstIndex(where: { $0.id == word.id }) {
            wordBank[index] = word
            saveWordBank(wordBank)
        } else {
            print("Error: Word not found in word bank.")
        }
    }
}