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
    @State private var showCopyAlert = false // State to control the alert visibility

    private let translationService = TranslationService()

    var body: some View {
        VStack {
            // Input TextField with Translate Button
            TextField("Enter word in English or Japanese", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .frame(height: 50)

            HStack {
                // Clear input
                Button(action: {
                    inputText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .padding()

                // Translate input
                Button(action: {
                    translateInput()
                }) {
                    Image(systemName: "globe")
                }
                .padding()

                // Read text aloud
                Button(action: {
                    if JapaneseIdentifier.shared.isJapanese(inputText) {
                        SpeechManager.shared.readJapanese(text: inputText)
                    } else if !displayedText.isEmpty {
                        SpeechManager.shared.readJapanese(text: displayedText)
                    }
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .padding()

                // Copy translated text to clipboard
                Button(action: {
                    copyToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .padding()
                .disabled(displayedText.isEmpty) // Disable if there's no translated text
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
        .alert("Copied to Clipboard", isPresented: $showCopyAlert) {
            Button("OK", role: .cancel) {}
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

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = displayedText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayedText, forType: .string)
        #endif

        // Show the "Copied to Clipboard" alert
        showCopyAlert = true
    }
}

#Preview {
    TranslationView()
}
