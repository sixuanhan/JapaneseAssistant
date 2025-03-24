//
//  ContentView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 12/19/24.
//

import SwiftUI

struct ContentView: View {
    enum tab {
        case home
        case practice
        case list
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(tab.home)
            
            PracticeView(wordList: [
                Word(id: UUID(), Phonetic: "こんにちは", Kanji: "", English: "Hello", example: "こんにちは、私の名前はジョンです", nextDueDate: Date()),
                Word(id: UUID(), Phonetic: "ありがとう", Kanji: "", English: "Thank you", example: "ありがとう、お願いします", nextDueDate: Date()),
                Word(id: UUID(), Phonetic: "くもり", Kanji: "曇り", English: "Cloudy", example: "今日はくもりです", nextDueDate: Date())
            ])
                .tabItem {
                    Label("Practice", systemImage: "pencil")
                }
                .tag(tab.practice)
            
            ListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .tag(tab.list)
        }
    }
}

#Preview {
    ContentView()
}
