//
//  ContentView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 12/19/24.
//

import SwiftUI

struct ContentView: View {
    enum tab {
        case translation
        case practice
        case list
        case knowledge
        case chat
    }

    var body: some View {
        TabView {         
            ListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .tag(tab.list)
            
            KnowledgeView()
                .tabItem {
                    Label("Knowledge", systemImage: "book")
                }
                .tag(tab.knowledge)

            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "pencil")
                }
                .tag(tab.practice)
           
            TranslationView()
                .tabItem {
                    Label("Translation", systemImage: "text.bubble")
                }
                .tag(tab.translation)
            
//            ChatView()
//                .tabItem {
//                    Label("Chat", systemImage: "message")
//                }
//                .tag(tab.chat)
        }
    }
}

#Preview {
    ContentView()
}
