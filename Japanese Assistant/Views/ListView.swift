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

    private let speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            ZStack {
                VStack() {
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
                                    Text(side.rawValue.uppercased())
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .padding()
                                }
                            }
                            .onTapGesture {
                                showRankingView = true
                            }

                            // Subsequent rows: Display the filtered words in the specified order
                            ForEach(filteredWordList) { word in
                                GridRow {
                                    ForEach(order, id: \.self) { side in
                                        if side == .Phonetic {
                                            Text(word.Phonetic)
                                                .font(.body)
                                                .padding()
                                        } else if side == .Kanji {
                                            Text(word.Kanji)
                                                .font(.body)
                                                .padding()
                                        } else if side == .English {
                                            Text(word.English)
                                                .font(.body)
                                                .padding()
                                        }
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
                                    readJapanese(word.Phonetic)
                                }
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

    private func readJapanese(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        speechSynthesizer.speak(utterance)
    }

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
