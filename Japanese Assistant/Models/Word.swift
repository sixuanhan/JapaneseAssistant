//
//  Word.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import Foundation

struct Word: Codable, Identifiable {
    var id = UUID()
    var Phonetic: String
    var Kanji: String
    var English: String
    var example: String
    var nextDueDate: Date
}
