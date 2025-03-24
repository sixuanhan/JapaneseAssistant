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
            
            PracticeView()
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
