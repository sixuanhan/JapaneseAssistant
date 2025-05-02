//
//  PracticeView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct PracticeView: View {
    @State private var wordList: [Word] = [] // Filtered and shuffled word list
    @State private var hasStarted: Bool = false
    @State private var currentIndex = 0 // Track the current word index
    @State private var flipped: Bool = false

    var body: some View {
        VStack {
            if !hasStarted {
                if !wordList.isEmpty {
                    Button("Start Practice") {
                        hasStarted = true
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                Text("You have \(wordList.count) words to practice.")
                    .font(.title2)
                    .padding()
            } else {
                if currentIndex < wordList.count {
                    HStack {
                        Spacer()
                        Text("\(currentIndex + 1)/\(wordList.count)")
                            .font(.title2)
                            .padding()
                    }

                    Spacer()

                    // Show the current word's VWordCard
                    VWordCard(
                        word: wordList[currentIndex],
                        flipped: $flipped,
                        front: randomFront()
                    )
                    
                    if flipped {
                        // Show buttons after the card is flipped
                        HStack {
                            Button("Again") {
                                updateNextDueDate(minutes: 1)
                            }
                            .buttonStyle(.bordered)

                            Button("Hard") {
                                updateNextDueDate(minutes: 5)
                            }
                            .buttonStyle(.bordered)

                            Button("OK") {
                                updateNextDueDate(minutes: 60)
                            }
                            .buttonStyle(.bordered)

                            Button("Good") {
                                updateNextDueDate(days: 5)
                            }
                            .buttonStyle(.bordered)

                            Button("Easy") {
                                updateNextDueDate(days: 15)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                } else {
                    Spacer()
                    
                    Text("Practice Complete!")
                        .font(.title)
                        .padding()
                    Button("Finish") {
                        hasStarted = false
                        currentIndex = 0
                        loadAndShuffleWordList()
                    }
                }

                Spacer()
            }
        }
        .navigationTitle("Practice")
        .onAppear {
            loadAndShuffleWordList()
        }
    }

    // Randomly initialize the front of the card
    private func randomFront() -> Side {
        let side = Side.allCases.randomElement() ?? .Phonetic
        return side
    }

    // Update the nextDueDate and move to the next word
    private func updateNextDueDate(minutes: Int = 0, days: Int = 0) {
        if minutes == 0 {
            wordList[currentIndex].nextDueDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        } else {
            wordList[currentIndex].nextDueDate = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()
        }
        WordBankManager.shared.saveUpdatedWordToWordBank(word: wordList[currentIndex])
        moveToNextWord()
    }

    // Move to the next word and reset the flipped state
    private func moveToNextWord() {
        flipped = false
        currentIndex += 1
    }

    private func loadAndShuffleWordList() {
        let allWords = WordBankManager.shared.loadWordBank()
        wordList = allWords.filter { $0.nextDueDate <= Date() }.shuffled()
    }
}

#Preview {
    PracticeView()
}
