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
    var knowledgeCards: [Knowledge]
}
