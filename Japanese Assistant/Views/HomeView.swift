//
//  HomeView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct HomeView: View {
    @State private var inputText: String = ""
    @State private var vocabList: [String] = []
    private let translationService = TranslationService()

    var body: some View {
       VStack {
           TextField("Enter word in English or Chinese", text: $inputText)
               .textFieldStyle(RoundedBorderTextFieldStyle())
               .padding()

           Button(action: addWord) {
               Text("Add")
                   .padding()
                   .background(Color.blue)
                   .foregroundColor(.white)
                   .cornerRadius(8)
           }

           List(vocabList, id: \.self) { word in
               Text(word)
           }
       }
       .padding()
    }

    func addWord() {
        // translationService.translate(text: inputText) { translatedText in
        //     if let translatedText = translatedText {
        //         vocabList.append(translatedText)
        //         inputText = ""
        //     }
        // }
    }
}

#Preview {
    HomeView()
}
