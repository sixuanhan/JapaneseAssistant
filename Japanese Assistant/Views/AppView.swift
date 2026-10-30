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
        case practice
        case sampleSentences
        case knowledge
        case translation
        case profile
    }

    var body: some View {
        TabView {
            ListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .tag(Tab.list)

            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "pencil")
                }
                .tag(Tab.practice)

            SampleSentencesView()
                .tabItem {
                    Label("Sample Sentences", systemImage: "text.quote")
                }
                .tag(Tab.sampleSentences)

            KnowledgeView()
                .tabItem {
                    Label("Knowledge", systemImage: "book")
                }
                .tag(Tab.knowledge)

            TranslationView()
                .tabItem {
                    Label("Translation", systemImage: "text.bubble")
                }
                .tag(Tab.translation)

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
