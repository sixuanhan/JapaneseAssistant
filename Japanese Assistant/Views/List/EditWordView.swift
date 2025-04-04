//
//  EditWordView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI
import WebKit

struct EditWordView: View {
    @State private var phonetic: String
    @State private var kanji: String
    @State private var english: String
    @State private var example: String
    @State private var showWebView = false
    @Environment(\.dismiss) var dismiss
    var word: Word

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

                    Button {
                        showWebView = true // Show the overlay with the web view
                    } label: {
                        Text("Search word")
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
            .sheet(isPresented: $showWebView) {
                WebView(url: URL(string: "https://takoboto.jp/?q=\(phonetic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!)
            }
        }
    }

    private func saveChanges() {
        var wordList = WordBankManager.shared.loadWordBank()
        if let index = wordList.firstIndex(where: { $0.id == word.id }) {
            wordList[index].Phonetic = phonetic
            wordList[index].Kanji = kanji
            wordList[index].English = english
            wordList[index].example = example
            WordBankManager.shared.saveWordBank(wordList)
        }
        dismiss()
    }

    private func deleteWord() {
        var wordList = WordBankManager.shared.loadWordBank()
        wordList.removeAll { $0.id == word.id }
        WordBankManager.shared.saveWordBank(wordList)
        dismiss()
    }

    private func dateFormatter(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - WebView for Displaying the Webpage
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
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