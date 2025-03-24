//
//  VWordCard.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct VWordCard: View {
    var word: Word

    @Binding private var flipped: Bool

    @State private var front: Side = .Phonetic

    init(word: Word, flipped: Binding<Bool>, front: Side) {
        self.word = word
        self._flipped = flipped
        self.front = front
    }

    var body: some View {
        VStack {
            if flipped {
                // Show all three aspects and the example
                VStack(spacing: 8) {
                    Text("\(word.Phonetic)")
                        .font(.title2)
                        .fontWeight(.bold)
                    if word.Kanji != "" {
                        Text("\(word.Kanji)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("\(word.English)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Divider()
                    Text(word.example)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .padding(.top, 8)
                }
                .padding()
            } else {
                // Show only the front aspect
                if front == .Phonetic {
                    Text(word.Phonetic)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                } else if front == .Kanji {
                    if word.Kanji == "" {
                        Text(word.Phonetic)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding()
                    } else {
                        Text(word.Kanji)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding()
                    }
                } else if front == .English {
                    Text(word.English)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5, x: 0, y: 2)
        .onTapGesture {
            flipped.toggle()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VWordCard(word: Word(id: UUID(), Phonetic: "くもり", Kanji: "曇り", English: "Cloudy", example: "今日はくもりです", nextDueDate: Date()), 
    flipped: .constant(false),
    front: .Phonetic)
}
