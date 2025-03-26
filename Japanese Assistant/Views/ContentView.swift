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
    }

    var body: some View {
        TabView {         
            ListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .tag(tab.list)

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
        }
    }
}

#Preview {
    ContentView()
}
