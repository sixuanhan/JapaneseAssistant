//
//  ContentView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 12/19/24.
//

import SwiftUI

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var vocabList: [String] = []
    private let translationService = TranslationService()

    var body: some View {
//        VStack {
//            TextField("Enter word in English or Chinese", text: $inputText)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .padding()
//
//            Button(action: addWord) {
//                Text("Add")
//                    .padding()
//                    .background(Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//            }
//
//            List(vocabList, id: \.self) { word in
//                Text(word)
//            }
//        }
//        .padding()
        
        ListView(wordList: [
            Word(id: UUID(), Phonetic: "こんにちは", Kanji: "", English: "Hello", example: "こんにちは、私の名前はジョンです", nextDueDate: Date()),
            Word(id: UUID(), Phonetic: "ありがとう", Kanji: "", English: "Thank you", example: "ありがとう、お願いします", nextDueDate: Date()),
            Word(id: UUID(), Phonetic: "くもり", Kanji: "曇り", English: "Cloudy", example: "今日はくもりです", nextDueDate: Date())
        ])
    }

    func addWord() {
        translationService.translate(text: inputText) { translatedText in
            if let translatedText = translatedText {
                vocabList.append(translatedText)
                inputText = ""
            }
        }
    }
}

#Preview {
    ContentView()
}
