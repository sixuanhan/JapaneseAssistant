//
//  SpeechManager.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/25/25.
//

import Foundation
import AVFAudio

class SpeechManager {
    static let shared = SpeechManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    func readJapanese(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        speechSynthesizer.speak(speechUtterance)
    }
}
