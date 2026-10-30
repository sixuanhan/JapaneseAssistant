import SwiftUI

struct PhoneticGroupSection: View {
    let wordID: UUID
    let phonetic: String
    @Binding var selectedMemberIDs: Set<UUID>?
    @State private var words: [Word] = []
    @State private var search = ""
    @State private var automaticMembers: Set<UUID> = []

    private func updateAutomaticMembers() {
        var proposed = words
        if let index = proposed.firstIndex(where: { $0.id == wordID }) {
            proposed[index].Phonetic = phonetic
        } else {
            proposed.append(Word(id: wordID, Phonetic: phonetic, Kanji: "", English: "",
                                 example: "", nextDueDate: Date()))
        }
        let preview = PhoneticGrouping.reconcile(proposed, previous: words)
        guard let groupID = preview.first(where: { $0.id == wordID })?.phoneticGroupId else {
            automaticMembers = []
            return
        }
        automaticMembers = Set(preview.filter { $0.id != wordID && $0.phoneticGroupId == groupID }.map(\.id))
    }

    private var members: Set<UUID> { selectedMemberIDs ?? automaticMembers }

    var body: some View {
        let memberIDs = members
        Section("Phonetic Group") {
            Text("Exact phonetic matches are grouped automatically on Save. Add or remove similar-sounding words below.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if memberIDs.isEmpty {
                Text("No phonetic group members.").foregroundStyle(.secondary)
            }
            ForEach(words.filter { memberIDs.contains($0.id) }) { word in
                HStack {
                    label(for: word)
                    Spacer()
                    Button(role: .destructive) {
                        var selection = members
                        selection.remove(word.id)
                        selectedMemberIDs = selection
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(word.displayText) from phonetic group")
                }
            }
            WordGroupSearch(words: words, query: $search,
                            excludedIDs: memberIDs.union([wordID]),
                            placeholder: "Search similar-sounding words...",
                            showsPhonetic: true, showsAddIcon: true) { word in
                var selection = members
                selection.insert(word.id)
                if let groupID = word.phoneticGroupId {
                    selection.formUnion(words.filter {
                        $0.id != wordID && $0.phoneticGroupId == groupID
                    }.map(\.id))
                }
                selectedMemberIDs = selection
            }
        }
        .onAppear {
            words = WordBankManager.shared.loadWordBank()
            updateAutomaticMembers()
        }
        .onChange(of: phonetic) { _, _ in
            selectedMemberIDs = nil
            updateAutomaticMembers()
        }
        .onChange(of: wordID) { _, _ in
            words = WordBankManager.shared.loadWordBank()
            selectedMemberIDs = nil
            updateAutomaticMembers()
        }
    }

    private func label(for word: Word) -> some View {
        VStack(alignment: .leading) {
            Text(word.displayText)
            Text("\(word.Phonetic) · \(word.English)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}