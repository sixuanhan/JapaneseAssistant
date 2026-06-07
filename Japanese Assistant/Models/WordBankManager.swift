//
//  WordBankManager.swift
//  Japanese Assistant
//
//  Offline-first facade. All UI reads and writes hit the local
//  UserDefaults cache via LocalDataStore (so they never block on the
//  network). Writes additionally notify AuthViewModel, which queues a
//  Firestore sync that replays when connectivity returns.
//

import Foundation

class WordBankManager {
    static let shared = WordBankManager()

    @MainActor
    func loadWordBank() -> [Word] {
        let uid = AuthViewModel.shared?.userSession?.uid
        return LocalDataStore.loadWordBank(uid: uid)
    }

    @MainActor
    func saveWordBank(_ wordBank: [Word]) {
        if let auth = AuthViewModel.shared, auth.userSession != nil {
            // Signed in: AuthViewModel persists locally AND queues cloud sync.
            auth.setWordBank(wordBank)
        } else {
            // Signed out: keep the legacy global blob alive so the data
            // is preserved and migrated on first sign-in.
            LocalDataStore.saveWordBank(wordBank, uid: nil)
        }
    }

    @MainActor
    func saveUpdatedWordToWordBank(word: Word) {
        var wordBank = loadWordBank()
        if let index = wordBank.firstIndex(where: { $0.id == word.id }) {
            wordBank[index] = word
            saveWordBank(wordBank)
        } else {
            print("Error: Word not found in word bank.")
        }
    }
}

