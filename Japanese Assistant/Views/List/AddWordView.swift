//
//  AddWordView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct AddWordView: View {
    @State private var inputText: String = ""
    @State private var phonetic = ""
    @State private var kanji = ""
    @State private var english = ""
    @State private var example = ""
    @State private var isTranslating = false // Track if translation is in progress
    @State private var showSaveConfirmation = false // Track if the "Saved Successfully" popup should be shown

    private let translationService = TranslationService()

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    // Input TextField with Translate Button
                    HStack {
                        TextField("Enter word in English or Japanese", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()

                        Button(action: {
                            translateInput()
                        }) {
                            Image(systemName: "globe")
                        }
                        .padding()
                        .disabled(inputText.isEmpty || isTranslating) // Disable if input is empty or translating
                    }

                    if isTranslating {
                        ProgressView("Translating...")
                            .padding()
                    }

                    // Form to display and edit the translated word
                    Form {
                        Section {
                            TextField("Phonetic", text: $phonetic)
                            TextField("Kanji, leave blank if none", text: $kanji)
                            TextField("English translation", text: $english)
                            TextField("Example Sentence, optional", text: $example)
                        }
                    }
                }
                .navigationTitle("Add Word")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveWord()
                        }
                        .disabled(phonetic.isEmpty || english.isEmpty) // Disable save if required fields are empty
                    }
                }

                // "Saved Successfully" popup
                if showSaveConfirmation {
                    VStack {
                        Spacer()
                        Text("Saved Successfully")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        Spacer().frame(height: 50) // Adjust position above the bottom
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showSaveConfirmation)
                }
            }
        }
    }

    // Translate the input text and populate the form fields
    private func translateInput() {
        isTranslating = true
        translationService.translate(text: inputText) { word in
            DispatchQueue.main.async {
                isTranslating = false
                if let word = word {
                    phonetic = word.Phonetic
                    kanji = word.Kanji
                    english = word.English
                    example = word.example
                } else {
                    print("Translation failed.")
                }
            }
        }
    }

    // Save the new word to the word bank
    private func saveWord() {
        let newWord = Word(
            Phonetic: phonetic,
            Kanji: kanji,
            English: english,
            example: example,
            nextDueDate: Date()
        )
        var wordList = WordBankManager.shared.loadWordBank()
        wordList.append(newWord)
        WordBankManager.shared.saveWordBank(wordList)

        // Show "Saved Successfully" popup
        showSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveConfirmation = false
        }
    }
}

#Preview {
    AddWordView()
}
