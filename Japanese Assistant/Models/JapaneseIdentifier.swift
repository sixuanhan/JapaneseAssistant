//
//  JapaneseIdentifier.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/25/25.
//

import Foundation

class JapaneseIdentifier {
    static let shared = JapaneseIdentifier()

    func isJapanese(_ text: String) -> Bool {
        return text.range(of: "\\p{Han}|\\p{Hiragana}|\\p{Katakana}", options: .regularExpression) != nil
    }

    func isKanji(_ text: String) -> Bool {
        return text.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
}