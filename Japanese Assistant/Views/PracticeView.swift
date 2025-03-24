//
//  PracticeView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct PracticeView: View {
    @State private var wordList: [Word] // Filtered and shuffled word list
    @State private var currentIndex = 0 // Track the current word index
    @State private var flipped: Bool = false

    init() {
        wordList = WordBankManager.shared.loadWordBank()
        // Filter words with nextDueDate earlier than now and shuffle them
        let dueWords = wordList.filter { $0.nextDueDate <= Date() }.shuffled()
        _wordList = State(initialValue: dueWords)
    }

    var body: some View {
        VStack {
            if currentIndex < wordList.count {
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
                            updateNextDueDate(minutes: 6)
                        }
                        .buttonStyle(.bordered)

                        Button("Good") {
                            updateNextDueDate(minutes: 10)
                        }
                        .buttonStyle(.bordered)

                        Button("Easy") {
                            updateNextDueDate(days: 5)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            } else {
                // Show a completion message when all words are practiced
                Text("Practice Complete!")
                    .font(.title)
                    .padding()
            }
        }
        .navigationTitle("Practice")
    }

    // Randomly initialize the front of the card
    private func randomFront() -> Side {
        return Side.allCases.randomElement() ?? .Phonetic
    }

    // Update the nextDueDate and move to the next word
    private func updateNextDueDate(minutes: Int = 0, days: Int = 0) {
        wordList[currentIndex].nextDueDate = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ??
                                             Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        moveToNextWord()
    }

    // Move to the next word and reset the flipped state
    private func moveToNextWord() {
        flipped = false
        currentIndex += 1
    }
}

#Preview {
    PracticeView()
}