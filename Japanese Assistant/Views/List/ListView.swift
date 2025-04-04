//
//  ListView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI
import AVFoundation

struct ListView: View {
    @State private var wordList: [Word] = [] // Load word bank from UserDefaults
    @State private var filteredWordList: [Word] = [] // Filtered word list based on search query
    @State private var searchQuery: String = "" // Search query for filtering
    @State var order = [Side.Phonetic, Side.Kanji, Side.English]
    @State private var showRankingView = false
    @State private var showAddWordView = false
    @State private var showEditWordView = false
    @State private var selectedWord: Word? // Track the word to be edited

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    // Search Bar
                    TextField("Search words...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .onChange(of: searchQuery) {
                            filterWordList()
                        }

                    ScrollView {
                        Grid {
                            // First row: Display the order
                            GridRow {
                                ForEach(order, id: \.self) { side in
                                    headerText(for: side)
                                }
                            }
                            .onTapGesture {
                                showRankingView = true
                            }

                            // Subsequent rows: Display the filtered words in the reverse order
                            ForEach(filteredWordList.reversed(), id: \.id) { word in
                                wordRow(for: word)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        print("Refreshing word list...")
                        reloadWordList() // Reload the word list when the user pulls down
                    }
                }

                // Floating + button
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showAddWordView = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            .padding()
                            .offset(x: -geometry.safeAreaInsets.trailing, y: -geometry.safeAreaInsets.bottom)
                        }
                    }
                }
            }
            .navigationTitle("Word List: \(wordList.count) words")
            .onAppear {
                reloadWordList()
            }
            .sheet(isPresented: $showRankingView) {
                RankingView(order: $order)
            }
            .sheet(isPresented: $showAddWordView) {
                AddWordView()
            }
            .sheet(isPresented: Binding(
                get: { showEditWordView && selectedWord != nil },
                set: { if !$0 { showEditWordView = false; selectedWord = nil } }
            )) {
                if let word = selectedWord {
                    EditWordView(word: word)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func headerText(for side: Side) -> some View {
        Text(side.rawValue.uppercased())
            .font(.headline)
            .foregroundColor(.primary)
            .padding()
    }

    private func wordRow(for word: Word) -> some View {
        GridRow {
            ForEach(order, id: \.self) { side in
                wordText(for: word, side: side)
            }

            Button(action: {
                selectedWord = word // Set the selected word
                showEditWordView = true // Show the EditWordView
                print("Edit word: \(word.Phonetic)")
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .onTapGesture {
            SpeechManager.shared.readJapanese(text: word.Phonetic)
        }
    }

    private func wordText(for word: Word, side: Side) -> some View {
        switch side {
        case .Phonetic:
            return Text(word.Phonetic)
                .font(.body)
                .padding()
        case .Kanji:
            return Text(word.Kanji)
                .font(.body)
                .padding()
        case .English:
            return Text(word.English)
                .font(.body)
                .padding()
        }
    }

    // MARK: - Helper Methods

    private func reloadWordList() {
        wordList = WordBankManager.shared.loadWordBank()
        filterWordList() // Ensure the filtered list is updated
    }

    private func filterWordList() {
        if searchQuery.isEmpty {
            filteredWordList = wordList
        } else {
            filteredWordList = wordList.filter { word in
                word.Phonetic.localizedCaseInsensitiveContains(searchQuery) ||
                word.Kanji.localizedCaseInsensitiveContains(searchQuery) ||
                word.English.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
}

#Preview {
    ListView()
}
