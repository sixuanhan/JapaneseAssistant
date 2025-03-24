//
//  Word.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import Foundation

struct Word: Codable, Identifiable {
    var id = UUID()
    let Phonetic: String
    let Kanji: String
    let English: String
    let example: String
    var nextDueDate: Date
}
