//
//  KnowledgeManager.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 4/3/25.
//

import Foundation

class KnowledgeManager {
    static let shared = KnowledgeManager()

    private let knowledgeKey = "KnowledgeCards"
        
    func loadKnowledgeCards() -> [Knowledge] {
        if let data = UserDefaults.standard.data(forKey: knowledgeKey),
           let decoded = try? JSONDecoder().decode([Knowledge].self, from: data) {
            return decoded
        }
        return []
    }

    func saveKnowledgeCards(_ knowledgeCards: [Knowledge]) {
        if let encoded = try? JSONEncoder().encode(knowledgeCards) {
            UserDefaults.standard.set(encoded, forKey: knowledgeKey)
        }
    }

    func saveUpdatedWordToWordBank(knowledge: Knowledge) {
        var knowledgeCards = loadKnowledgeCards()

        // Find the index of the knowledge to update
        if let index = knowledgeCards.firstIndex(where: { $0.id == knowledge.id }) {
            knowledgeCards[index] = knowledge
            saveKnowledgeCards(knowledgeCards)
        } else {
            // If not found, append the new knowledge
            knowledgeCards.append(knowledge)
            saveKnowledgeCards(knowledgeCards)
        }
    }

    func deleteKnowledge(knowledge: Knowledge) {
        var knowledgeCards = loadKnowledgeCards()
        knowledgeCards.removeAll { $0.id == knowledge.id }
        saveKnowledgeCards(knowledgeCards)
    }
}
