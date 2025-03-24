//
//  AddWordView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct AddWordView: View {
    @State private var phonetic = ""
    @State private var kanji = ""
    @State private var english = ""
    @State private var example = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section() {
                    TextField("Phonetic", text: $phonetic)
                    TextField("Kanji, leave blank if none", text: $kanji)
                    TextField("English translation", text: $english)
                    TextField("Example Sentence, optional", text: $example)
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
        }
    }

    private func saveWord() {
        let newWord = Word(
            Phonetic: phonetic,
            Kanji: kanji,
            English: english,
            example: example,
            nextDueDate: Date()
        )

        // Retrieve the existing word bank from UserDefaults
        var wordBank = loadWordBank()
        wordBank.append(newWord)

        // Save the updated word bank back to UserDefaults
        if let encoded = try? JSONEncoder().encode(wordBank) {
            UserDefaults.standard.set(encoded, forKey: "WordBank")
        }
    }

    private func loadWordBank() -> [Word] {
        if let data = UserDefaults.standard.data(forKey: "WordBank"),
           let decoded = try? JSONDecoder().decode([Word].self, from: data) {
            return decoded
        }
        return []
    }
}

#Preview {
    AddWordView()
}
