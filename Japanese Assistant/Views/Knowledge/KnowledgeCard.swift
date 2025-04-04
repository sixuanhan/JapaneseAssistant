//
//  KnowledgeCard.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 4/3/25.
//

import SwiftUI

struct KnowledgeCard: View {
    @Binding var knowledge: Knowledge // Bind to a `Knowledge` object
    @State private var isEditing = false

    var body: some View {
        VStack {
            if isEditing {
                TextEditor(text: $knowledge.text)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .frame(minHeight: 150)
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(knowledge.text)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .frame(minHeight: 150)
                    }
                }
            }

            HStack {
                Spacer()

                if isEditing {
                    HStack {
                        Button("Cancel") {
                            isEditing = false
                        }
                        .padding(.horizontal)

                        Spacer()

                        Button("Delete") {
                            KnowledgeManager.shared.deleteKnowledge(knowledge: knowledge)
                            isEditing = false
                        }
                        .padding(.horizontal)

                        Spacer()
                        
                        Button("Save") {
                            KnowledgeManager.shared.saveUpdatedWordToWordBank(knowledge: knowledge)
                            isEditing = false
                        }
                        .padding(.horizontal)
                    }   
                } else {
                    Button("Edit") {
                        isEditing = true
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }
}

#Preview {
    KnowledgeCard(knowledge: .constant(Knowledge(text: "This is a sample text for the knowledge card.")))
}
