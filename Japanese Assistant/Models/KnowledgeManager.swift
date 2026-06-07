//
//  KnowledgeManager.swift
//  Japanese Assistant
//
//  Offline-first facade. Reads and writes hit the local UserDefaults
//  cache via LocalDataStore. Writes additionally notify AuthViewModel,
//  which queues a Firestore sync that replays when connectivity returns.
//

import Foundation

class KnowledgeManager {
    static let shared = KnowledgeManager()

    @MainActor
    func loadKnowledgeCards() -> [Knowledge] {
        let uid = AuthViewModel.shared?.userSession?.uid
        return LocalDataStore.loadKnowledgeCards(uid: uid)
    }

    @MainActor
    func saveKnowledgeCards(_ knowledgeCards: [Knowledge]) {
        if let auth = AuthViewModel.shared, auth.userSession != nil {
            auth.setKnowledgeCards(knowledgeCards)
        } else {
            LocalDataStore.saveKnowledgeCards(knowledgeCards, uid: nil)
        }
    }

    /// Updates an existing card in place, or appends it if new.
    @MainActor
    func saveUpdatedWordToWordBank(knowledge: Knowledge) {
        var knowledgeCards = loadKnowledgeCards()
        if let index = knowledgeCards.firstIndex(where: { $0.id == knowledge.id }) {
            knowledgeCards[index] = knowledge
        } else {
            knowledgeCards.append(knowledge)
        }
        saveKnowledgeCards(knowledgeCards)
    }

    @MainActor
    func deleteKnowledge(knowledge: Knowledge) {
        var knowledgeCards = loadKnowledgeCards()
        knowledgeCards.removeAll { $0.id == knowledge.id }
        saveKnowledgeCards(knowledgeCards)
    }
}

