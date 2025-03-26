//
//  TranslationView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/25/25.
//

import SwiftUI

struct TranslationView: View {
    @State private var inputText: String = ""
    @State private var isTranslating = false
    @State private var displayedText = ""

    private let translationService = TranslationService()

    var body: some View {
        VStack {
            // Input TextField with Translate Button
            TextField("Enter word in English or Japanese", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .frame(height: 50)

            HStack {
                // clear input
                Button(action: {
                    inputText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .padding()

                Button(action: {
                    translateInput()
                }) {
                    Image(systemName: "globe")
                }
                .padding()

                Button(action: {
                    if JapaneseIdentifier.shared.isJapanese(inputText) {
                        SpeechManager.shared.readJapanese(text: inputText)
                    } else if !displayedText.isEmpty {
                        SpeechManager.shared.readJapanese(text: displayedText)
                    }
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }
            .padding()
            .disabled(inputText.isEmpty || isTranslating) // Disable if input is empty or translating

            if isTranslating {
                ProgressView("Translating...")
                    .padding()
            }

            // Display the translated word
            Text(displayedText)
                .padding()
        }
    }

    private func translateInput() {
        isTranslating = true
        translationService.simpleTranslate(text: inputText) { translatedText in
            DispatchQueue.main.async {
                isTranslating = false
                if let text = translatedText {
                    displayedText = text
                } else {
                    print("Translation failed.")
                }
            }
        }
    }
}

#Preview {
    TranslationView()
}
