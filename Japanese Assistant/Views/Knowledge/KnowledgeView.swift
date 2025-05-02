//
//  KnowledgeView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 4/3/25.
//

import SwiftUI

struct KnowledgeView: View {
    @State private var knowledgeCards: [Knowledge] = []
    @State private var searchQuery: String = ""

    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                TextField("Search knowledge...", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: searchQuery) {
                        filterCards()
                    }

                // List of Knowledge Cards
                List {
                    ForEach($knowledgeCards) { $knowledge in
                        NavigationLink(destination: KnowledgeCard(knowledge: $knowledge)) {
                            Text(knowledge.text.components(separatedBy: "\n").first ?? knowledge.text)
                                .padding()
                        }
                    }
                }
                .refreshable {
                    knowledgeCards = KnowledgeManager.shared.loadKnowledgeCards()
                }
            }
            .navigationTitle("Knowledge")
            .onAppear {
                knowledgeCards = KnowledgeManager.shared.loadKnowledgeCards()
            }
        }
    }

    private func filterCards() {
        if searchQuery.isEmpty {
            knowledgeCards = KnowledgeManager.shared.loadKnowledgeCards()
        } else {
            knowledgeCards = KnowledgeManager.shared.loadKnowledgeCards().filter {
                $0.text.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
}

#Preview {
    KnowledgeView()
}
