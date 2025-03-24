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
}