//
//  AppView.swift
//  Japanese Assistant
//
//  Tab shell shown after the user signs in.
//

import SwiftUI

struct AppView: View {
    enum Tab {
        case list
        case knowledge
        case practice
        case translation
        case chat
        case profile
    }

    var body: some View {
        TabView {
            ListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .tag(Tab.list)

            KnowledgeView()
                .tabItem {
                    Label("Knowledge", systemImage: "book")
                }
                .tag(Tab.knowledge)

            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "pencil")
                }
                .tag(Tab.practice)

            TranslationView()
                .tabItem {
                    Label("Translation", systemImage: "text.bubble")
                }
                .tag(Tab.translation)

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .tag(Tab.chat)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
    }
}

#Preview {
    AppView()
        .environmentObject(AuthViewModel())
}
