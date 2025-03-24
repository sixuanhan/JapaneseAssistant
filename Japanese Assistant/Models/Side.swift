//
//  Side.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import Foundation

enum Side: String, CaseIterable, Identifiable, Equatable {
    case Phonetic
    case Kanji
    case English

    var id: String { rawValue }
}