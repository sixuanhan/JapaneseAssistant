import SwiftUI

struct WordGroupSearch: View {
    let words: [Word]
    @Binding var query: String
    var excludedIDs: Set<UUID> = []
    var selectedIDs: Set<UUID> = []
    var placeholder = "Search vocab..."
    var showsPhonetic = false
    var showsAddIcon = false
    let onSelect: (Word) -> Void

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Word] {
        let search = trimmedQuery
        guard !search.isEmpty else { return [] }
        return words.filter { word in
            !excludedIDs.contains(word.id)
                && (word.Phonetic.localizedCaseInsensitiveContains(search)
                    || word.Kanji.localizedCaseInsensitiveContains(search)
                    || word.English.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        TextField(placeholder, text: $query)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        if trimmedQuery.isEmpty {
            Text("Type a word to search")
                .foregroundStyle(.secondary)
        } else {
            let matches = results
            if matches.isEmpty {
                Text("No matching vocab words.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches) { word in
                    Button {
                        onSelect(word)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(word.displayText)
                                Text(showsPhonetic ? "\(word.Phonetic) · \(word.English)" : word.English)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedIDs.contains(word.id) {
                                Image(systemName: "checkmark")
                            } else if showsAddIcon {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}