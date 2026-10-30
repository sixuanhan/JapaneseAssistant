import SwiftUI

struct PhoneticGroupSection: View {
    let wordID: UUID
    let phonetic: String
    @Binding var selectedMemberIDs: Set<UUID>?
    @State private var words: [Word] = []
    @State private var search = ""

    private var automaticMembers: Set<UUID> {
        var proposed = words
        if let index = proposed.firstIndex(where: { $0.id == wordID }) {
            proposed[index].Phonetic = phonetic
        } else {
            proposed.append(Word(id: wordID, Phonetic: phonetic, Kanji: "", English: "",
                                 example: "", nextDueDate: Date()))
        }
        let preview = PhoneticGrouping.reconcile(proposed, previous: words)
        guard let groupID = preview.first(where: { $0.id == wordID })?.phoneticGroupId else { return [] }
        return Set(preview.filter { $0.id != wordID && $0.phoneticGroupId == groupID }.map(\.id))
    }

    private var members: Set<UUID> { selectedMemberIDs ?? automaticMembers }

    private var results: [Word] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return words.filter {
            $0.id != wordID && !members.contains($0.id)
                && ($0.Phonetic.localizedCaseInsensitiveContains(query)
                    || $0.Kanji.localizedCaseInsensitiveContains(query)
                    || $0.English.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        Section("Phonetic Group") {
            Text("Exact phonetic matches are grouped automatically on Save. Add or remove similar-sounding words below.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if members.isEmpty {
                Text("No phonetic group members.").foregroundStyle(.secondary)
            }
            ForEach(words.filter { members.contains($0.id) }) { word in
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
            TextField("Search similar-sounding words...", text: $search)
            ForEach(results) { word in
                Button {
                    var selection = members
                    selection.insert(word.id)
                    if let groupID = word.phoneticGroupId {
                        selection.formUnion(words.filter {
                            $0.id != wordID && $0.phoneticGroupId == groupID
                        }.map(\.id))
                    }
                    selectedMemberIDs = selection
                } label: {
                    HStack {
                        label(for: word)
                        Spacer()
                        Image(systemName: "plus.circle")
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear { words = WordBankManager.shared.loadWordBank() }
        .onChange(of: phonetic) { _, _ in selectedMemberIDs = nil }
        .onChange(of: wordID) { _, _ in
            words = WordBankManager.shared.loadWordBank()
            selectedMemberIDs = nil
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