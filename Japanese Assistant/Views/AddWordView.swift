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
                    }
                    .disabled(phonetic.isEmpty || english.isEmpty) // Disable save if required fields are empty
                }
            }
        }
    }
}

#Preview {
    AddWordView()
}
