//
//  EditWordView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//
//  Vocab-group mental model:
//  - `Word.vocabGroupId` is the source of truth for group membership.
//  - `selectedGroupIds` is a local editing set of sibling word ids
//    (never contains the edited word itself). Adding to it stages a
//    sibling for the group; removing from it stages a sibling for
//    orphaning (only when the user is staying in the group, not when
//    they're leaving it — see `saveChanges`).
//

import SwiftUI
import WebKit

struct EditWordView: View {
    @State private var phonetic: String
    @State private var kanji: String
    @State private var english: String
    @State private var example: String
    @State private var vocabGroupNote: String
    /// Sibling ids that will share `currentGroupId` after Save. Never
    /// includes `word.id`. Initialised in `loadExistingWords` from the
    /// word bank; edits by the user via the group section reflect
    /// intended post-save membership.
    @State private var selectedGroupIds: Set<UUID>
    /// The vocab group this word belongs to (or is about to be added to).
    /// `nil` means "not in a group". A fresh UUID is minted lazily the
    /// first time the user picks a sibling in the editor.
    @State private var currentGroupId: UUID?
    @State private var vocabGroupSearchQuery = ""
    @State private var isAddingToGroup = false
    @State private var allWords: [Word] = []
    @State private var showWebView = false
    @State private var isGeneratingGroupNote = false
    @State private var groupNoteRequestID = UUID()
    @StateObject private var chatViewModel = ChatViewModel()
    @Environment(\.dismiss) var dismiss
    var word: Word

    init(word: Word) {
        self.word = word
        _phonetic = State(initialValue: word.Phonetic)
        _kanji = State(initialValue: word.Kanji)
        _english = State(initialValue: word.English)
        _example = State(initialValue: word.example)
        _vocabGroupNote = State(initialValue: "")
        _selectedGroupIds = State(initialValue: Set())
        _currentGroupId = State(initialValue: word.vocabGroupId)
    }

    var body: some View {
        NavigationStack {
            Form {
                editWordSection
                vocabGroupSection
                vocabGroupNoteSection
                actionsSection
                nextDueSection
            }
            .navigationTitle("Edit Word")
            .toolbar { toolbarButtons }
            .sheet(isPresented: $showWebView) {
                WebView(url: URL(string: "https://takoboto.jp/?q=\(phonetic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!)
            }
            .onAppear {
                chatViewModel.setup()
                loadExistingWords()
                if !selectedGroupIds.isEmpty && vocabGroupNote.isEmpty {
                    updateVocabGroupNote()
                }
            }
        }
    }

    // MARK: - Sections

    private var editWordSection: some View {
        Section(header: Text("Edit Word")) {
            TextField("Phonetic", text: $phonetic)
            TextField("Kanji, leave blank if none", text: $kanji)
            TextField("English translation", text: $english)
            HStack {
                TextField("Example Sentence, optional", text: $example)
                Button(action: generateExample) {
                    Image(systemName: "wand.and.stars")
                }
                .disabled(phonetic.isEmpty && english.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var vocabGroupSection: some View {
        Section(header: Text("Vocab Group")) {
            if selectedGroupIds.isEmpty && currentGroupId == nil {
                joinGroupPrompt
            } else {
                groupMembershipEditor
            }
        }
    }

    @ViewBuilder
    private var vocabGroupNoteSection: some View {
        if !selectedGroupIds.isEmpty {
            Section(header: Text("Vocab Group Note")) {
                if isGeneratingGroupNote {
                    ProgressView("Generating note...")
                } else if vocabGroupNote.isEmpty {
                    Text("No vocab group selected.")
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.vertical) {
                        Text(vocabGroupNote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .frame(minHeight: 120, maxHeight: 180)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button(role: .destructive) {
                deleteWord()
            } label: {
                Text("Delete Word")
            }

            Button {
                showWebView = true
            } label: {
                Text("Search word")
            }
        }
    }

    private var nextDueSection: some View {
        Section {
            Text("Next Due Date: \(dateFormatter(date: word.nextDueDate))")
                .font(.caption)
        }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                saveChanges()
            }
            .disabled(phonetic.isEmpty || english.isEmpty)
        }
    }

    // MARK: - Vocab Group sub-sections

    /// Shown when the word is not in a group and the user has not asked
    /// to add one yet. Two states: a promotion button, or the search
    /// field that lets them pick the first sibling.
    @ViewBuilder
    private var joinGroupPrompt: some View {
        if isAddingToGroup {
            searchField
            searchResultsList(showsCheckmark: false) { existing in
                addWordToVocabGroup(existing)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("This word is not part of a vocab group yet.")
                    .foregroundColor(.secondary)
                Button("Add a word to vocab group") {
                    isAddingToGroup = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    /// Shown when the word is (or is being added to) a group: existing
    /// members with trash buttons, plus a search field to bring in more.
    @ViewBuilder
    private var groupMembershipEditor: some View {
        let members = selectedGroupWords()
        if !members.isEmpty {
            ForEach(members) { existing in
                HStack {
                    VStack(alignment: .leading) {
                        Text(existing.displayText)
                        Text(existing.English)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        toggleSelection(for: existing.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .padding(.vertical, 4)
            }
        }

        searchField
        searchResultsList(showsCheckmark: true) { existing in
            toggleSelection(for: existing.id)
        }
    }

    private var searchField: some View {
        TextField("Search vocab...", text: $vocabGroupSearchQuery)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }

    @ViewBuilder
    private func searchResultsList(showsCheckmark: Bool, onTap: @escaping (Word) -> Void) -> some View {
        if vocabGroupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Type a word to search")
                .foregroundColor(.secondary)
        } else if searchResults.isEmpty {
            Text("No matching vocab words.")
                .foregroundColor(.secondary)
        } else {
            ForEach(searchResults) { existing in
                Button {
                    onTap(existing)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(existing.displayText)
                            Text(existing.English)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if showsCheckmark && selectedGroupIds.contains(existing.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data helpers

    private func loadExistingWords() {
        let allWordBank = WordBankManager.shared.loadWordBank()
        // Refresh `currentGroupId` from the fresh word bank in case the
        // `Word` snapshot passed into `init` is stale (e.g., ListView's
        // cached `wordList` hadn't reloaded after another Edit sheet
        // just changed our vocabGroupId).
        if let freshSelf = allWordBank.first(where: { $0.id == word.id }) {
            currentGroupId = freshSelf.vocabGroupId
        }
        let existingWords = allWordBank.filter { $0.id != word.id }
        allWords = existingWords

        if let groupId = currentGroupId {
            let siblings = existingWords.filter { $0.vocabGroupId == groupId }
            if siblings.isEmpty {
                // Word carries a vocabGroupId but no siblings remain
                // (e.g., they were deleted on another device). Treat
                // this as "not in a group" so the UI offers the
                // "Add a word to vocab group" flow instead of an empty
                // members list with no explanation.
                currentGroupId = nil
                vocabGroupNote = ""
            } else {
                selectedGroupIds = Set(siblings.map { $0.id })
                if vocabGroupNote.isEmpty,
                   let group = VocabGroupManager.shared.loadVocabGroups().first(where: { $0.id == groupId }) {
                    vocabGroupNote = group.vocabGroupNote
                }
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedGroupIds.contains(id) {
            selectedGroupIds.remove(id)
        } else {
            selectedGroupIds.insert(id)
            if currentGroupId == nil {
                currentGroupId = UUID()
            }
        }
        // Membership changed — refresh the AI note. Fires only on real
        // user actions; hydration in `loadExistingWords` bypasses this.
        updateVocabGroupNote()
    }

    private func addWordToVocabGroup(_ word: Word) {
        selectedGroupIds.insert(word.id)
        if currentGroupId == nil {
            currentGroupId = UUID()
        }
        isAddingToGroup = false
        vocabGroupSearchQuery = ""
        updateVocabGroupNote()
    }

    private func selectedGroupWords() -> [Word] {
        allWords.filter { selectedGroupIds.contains($0.id) }
    }

    private var searchResults: [Word] {
        let query = vocabGroupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return []
        }
        return allWords.filter { word in
            word.Phonetic.lowercased().contains(query) ||
            word.Kanji.lowercased().contains(query) ||
            word.English.lowercased().contains(query)
        }
    }

    private func buildVocabGroupNotePrompt() -> [Word] {
        let currentWord = Word(
            id: word.id,
            Phonetic: phonetic,
            Kanji: kanji,
            English: english,
            example: example,
            nextDueDate: word.nextDueDate
        )
        return [currentWord] + allWords.filter { selectedGroupIds.contains($0.id) }
    }

    private func updateVocabGroupNote() {
        guard !selectedGroupIds.isEmpty else {
            vocabGroupNote = ""
            return
        }

        isGeneratingGroupNote = true
        // Debounce + stale-response guard: only the newest request may
        // touch `vocabGroupNote` / `isGeneratingGroupNote`.
        let requestID = UUID()
        groupNoteRequestID = requestID
        let groupWords = buildVocabGroupNotePrompt()

        chatViewModel.generateVocabGroupNote(for: groupWords, requestID: requestID) { note in
            if groupNoteRequestID == requestID {
                vocabGroupNote = note
                isGeneratingGroupNote = false
            }
        }
    }

    private func saveChanges() {
        let previousGroupId = word.vocabGroupId
        let updatedGroupId = selectedGroupIds.isEmpty ? nil : (currentGroupId ?? UUID())
        if currentGroupId == nil {
            currentGroupId = updatedGroupId
        }

        var wordList = WordBankManager.shared.loadWordBank()
        wordList = wordList.map { existing in
            // The edited word — always rewritten with the current form
            // fields and the (possibly nil) target group.
            if existing.id == word.id {
                return Word(
                    id: word.id,
                    Phonetic: phonetic,
                    Kanji: kanji,
                    English: english,
                    example: example,
                    nextDueDate: word.nextDueDate,
                    vocabGroupId: updatedGroupId
                )
            }

            // Words the user explicitly added to the selection: assign
            // them the (guaranteed non-nil) target group.
            if let updatedGroupId, selectedGroupIds.contains(existing.id) {
                var updated = existing
                updated.vocabGroupId = updatedGroupId
                return updated
            }

            // Former siblings that the user removed from the selection
            // while staying in the group: orphan them.
            //
            // Guarded by `updatedGroupId != nil` so that leaving the
            // group entirely (empty selection) doesn't dissolve it for
            // everyone — the previous version cleared every sibling's
            // vocabGroupId, silently disbanding the whole group.
            if updatedGroupId != nil,
               let previousGroupId,
               existing.vocabGroupId == previousGroupId,
               !selectedGroupIds.contains(existing.id) {
                var updated = existing
                updated.vocabGroupId = nil
                return updated
            }

            return existing
        }

        WordBankManager.shared.saveWordBank(wordList)

        if let updatedGroupId {
            let members = wordList.filter { $0.vocabGroupId == updatedGroupId }
            let group = VocabGroup(id: updatedGroupId, wordMembers: members, vocabGroupNote: vocabGroupNote)
            VocabGroupManager.shared.saveGroup(group, with: wordList)
        } else {
            // Ensure any group we just fully left gets cleaned up if it
            // is now empty.
            VocabGroupManager.shared.pruneEmptyGroups(with: wordList)
        }

        if let previousGroupId, previousGroupId != updatedGroupId {
            VocabGroupManager.shared.pruneEmptyGroups(with: wordList)
        }

        dismiss()
    }

    private func deleteWord() {
        let previousGroupId = word.vocabGroupId
        var wordList = WordBankManager.shared.loadWordBank()
        wordList.removeAll { $0.id == word.id }
        WordBankManager.shared.saveWordBank(wordList)
        if previousGroupId != nil {
            VocabGroupManager.shared.pruneEmptyGroups(with: wordList)
        }
        dismiss()
    }

    private func dateFormatter(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func generateExample() {
        chatViewModel.generateExampleSentence(for: preferredInputForExample()) { sentence in
            example = sentence
        }
    }

    /// Kanji > phonetic > english, mirroring `Word.displayText`'s fallback
    /// order but reading from the live form fields rather than the saved
    /// `Word` snapshot.
    private func preferredInputForExample() -> String {
        let trimmedKanji = kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKanji.isEmpty { return trimmedKanji }
        let trimmedPhonetic = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPhonetic.isEmpty { return trimmedPhonetic }
        return english
    }
}

// MARK: - WebView for Displaying the Webpage
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

#Preview {
    let koshiWord = Word(
        id: UUID(),
        Phonetic: "koshi",
        Kanji: "腰",
        English: "lower back",
        example: "腰が痛いです。",
        nextDueDate: Date(),
        vocabGroupId: UUID()
    )
    EditWordView(word: koshiWord)
}
