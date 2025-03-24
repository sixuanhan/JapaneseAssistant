//
//  EditWordView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct EditWordView: View {
    @State private var phonetic: String
    @State private var kanji: String
    @State private var english: String
    @State private var example: String
    @Environment(\.dismiss) var dismiss
    var word: Word // The word to be edited

    init(word: Word) {
        self.word = word
        _phonetic = State(initialValue: word.Phonetic)
        _kanji = State(initialValue: word.Kanji)
        _english = State(initialValue: word.English)
        _example = State(initialValue: word.example)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Edit Word")) {
                    TextField("Phonetic", text: $phonetic)
                    TextField("Kanji, leave blank if none", text: $kanji)
                    TextField("English translation", text: $english)
                    TextField("Example Sentence, optional", text: $example)
                }

                Section {
                    Button(role: .destructive) {
                        deleteWord()
                    } label: {
                        Text("Delete Word")
                    }
                }

                Section {
                    Text("Next Due Date: \(dateFormatter(date: word.nextDueDate))")
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Word")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(phonetic.isEmpty || english.isEmpty) // Disable save if required fields are empty
                }
            }
        }
    }

    private func saveChanges() {
        // Load the current word bank
        var wordList = WordBankManager.shared.loadWordBank()

        // Find the index of the word to be edited
        if let index = wordList.firstIndex(where: { $0.id == word.id }) {
            // Update the word's properties
            wordList[index].Phonetic = phonetic
            wordList[index].Kanji = kanji
            wordList[index].English = english
            wordList[index].example = example

            // Save the updated word bank back to UserDefaults
            WordBankManager.shared.saveWordBank(wordList)
        }

        // Dismiss the view
        dismiss()
    }

    private func deleteWord() {
        // Load the current word bank
        var wordList = WordBankManager.shared.loadWordBank()

        // Remove the word from the word bank
        wordList.removeAll { $0.id == word.id }

        // Save the updated word bank back to UserDefaults
        WordBankManager.shared.saveWordBank(wordList)

        // Dismiss the view
        dismiss()
    }

    private func dateFormatter(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    EditWordView(word: Word(
        id: UUID(),
        Phonetic: "こんにちは",
        Kanji: "こんにちは",
        English: "Hello",
        example: "こんにちは、私の名前はジョンです",
        nextDueDate: Date()
    ))
}