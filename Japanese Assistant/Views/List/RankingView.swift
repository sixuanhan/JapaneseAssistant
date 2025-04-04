//
//  RankingView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//

import SwiftUI

struct RankingView: View {
    @Binding var order: [Side] // Use a Binding to manage state from a parent view

    var body: some View {
        NavigationStack {
            List {
                ForEach(order) { side in
                    HStack {
                        Text(side.rawValue)
                            .font(.headline)
                            .padding()
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                }
                .onMove {IndexSet, destination in
                    order.move(fromOffsets: IndexSet, toOffset: destination)}
            }
        }
    }
}

@available(iOS 18.0, *)
#Preview {
    @Previewable @State var order = [Side.Phonetic, Side.Kanji, Side.English]
    RankingView(order: $order)
}
