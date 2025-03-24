//
//  ContentView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 12/19/24.
//

import SwiftUI

struct ContentView: View {
    enum tab {
        case practice
        case list
    }

    var body: some View {
        TabView {        
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
