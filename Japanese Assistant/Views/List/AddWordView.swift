//
//  AddWordView.swift
//  Japanese Assistant
//
//  Created by xuanxuan on 3/23/25.
//
//  Vocab-group mental model:
//  - `Word.vocabGroupId` is the source of truth for group membership.
//  - `selectedGroupIds` is a local editing set of *existing* word ids
//    that the user wants to bring into a group along with the new word.
//    A fresh `currentGroupId` is minted lazily the first time the user
//    picks a sibling. If any of the selected words already belonged to
//    a different group, `saveWord` prunes those source groups if they
//    end up empty after the move.
//

import SwiftUI

struct AddWordView: View {
    @State private var inputText: String = ""
    @State private var phonetic = ""
    @State private var kanji = ""
    @State private var english = ""
    @State private var example = ""
    @State private var vocabGroupNote = ""
    @State private var selectedGroupIds = Set<UUID>()
    @State private var currentGroupId: UUID?
    @State private var vocabGroupSearchQuery = ""
    @State private var allWords: [Word] = []
    @State private var isTranslating = false
    @State private var isGeneratingGroupNote = false
    @State private var groupNoteRequestID = UUID()
    @State private var showSaveConfirmation = false
    @StateObject private var chatViewModel = ChatViewModel()

    private let translationService = TranslationService()

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    translateBar
                    if isTranslating {
                        ProgressView("Translating...")
                            .padding()
                    }
                    Form {
                        editWordSection
                        vocabGroupSection
                        vocabGroupNoteSection
                    }
                }
                .navigationTitle("Add Word")
                .toolbar { toolbarButtons }

                if showSaveConfirmation {
                    savedConfirmationOverlay
                }
            }
            .onAppear {
                chatViewModel.setup()
                loadExistingWords()
            }
        }
    }

    // MARK: - Sections

    private var translateBar: some View {
        HStack {
            TextField("Enter word in English or Japanese", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: translateInput) {
                Image(systemName: "globe")
            }
            .padding()
            .disabled(inputText.isEmpty || isTranslating)
        }
    }

    private var editWordSection: some View {
        Section {
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
            TextField("Search vocab...", text: $vocabGroupSearchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if vocabGroupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Type a word to search")
                    .foregroundColor(.secondary)
            } else if matchingGroupWords.isEmpty {
                Text("No matching vocab words.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(matchingGroupWords) { existing in
                    Button {
                        toggleSelection(for: existing.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(existing.displayText)
                                Text(existing.English)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedGroupIds.contains(existing.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var vocabGroupNoteSection: some View {
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

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                saveWord()
            }
            .disabled(phonetic.isEmpty || english.isEmpty)
        }
    }

    private var savedConfirmationOverlay: some View {
        VStack {
            Spacer()
            Text("Saved Successfully")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
                .shadow(radius: 5)
            Spacer().frame(height: 50)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: showSaveConfirmation)
    }

    // MARK: - Data helpers

    private func translateInput() {
        isTranslating = true
        translationService.translate(text: inputText) { word in
            DispatchQueue.main.async {
                isTranslating = false
                if let word = word {
                    phonetic = word.Phonetic
                    kanji = word.Kanji
                    english = word.English
                    example = word.example
                } else {
                    print("Translation failed.")
                }
            }
        }
    }

    private func loadExistingWords() {
        allWords = WordBankManager.shared.loadWordBank()
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
        // Membership changed — refresh the AI note. Driven from the
        // user action so hydration paths don't fire an unnecessary call.
        updateVocabGroupNote()
    }

    private var matchingGroupWords: [Word] {
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
            Phonetic: phonetic,
            Kanji: kanji,
            English: english,
            example: example,
            nextDueDate: Date()
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

    private func saveWord() {
        let hasGroup = !selectedGroupIds.isEmpty
        let vocabGroupId = hasGroup ? (currentGroupId ?? UUID()) : nil
        let newWord = Word(
            Phonetic: phonetic,
            Kanji: kanji,
            English: english,
            example: example,
            nextDueDate: Date(),
            vocabGroupId: vocabGroupId
        )

        // Snapshot the group ids of every word we're about to move into
        // this new group so we can prune any that end up empty as a
        // result — otherwise a word moved from group H into the new
        // group would leave H behind as a stale record.
        let originalWordList = WordBankManager.shared.loadWordBank()
        let displacedGroupIds = Set(
            originalWordList
                .filter { selectedGroupIds.contains($0.id) }
                .compactMap { $0.vocabGroupId }
        ).subtracting(vocabGroupId.map { [$0] } ?? [])

        var wordList = originalWordList.map { existing -> Word in
            guard let vocabGroupId, selectedGroupIds.contains(existing.id) else {
                return existing
            }
            var updated = existing
            updated.vocabGroupId = vocabGroupId
            return updated
        }
        wordList.append(newWord)
        WordBankManager.shared.saveWordBank(wordList)

        if let vocabGroupId {
            let members = wordList.filter { $0.vocabGroupId == vocabGroupId }
            let vocabGroup = VocabGroup(id: vocabGroupId, wordMembers: members, vocabGroupNote: vocabGroupNote)
            VocabGroupManager.shared.saveGroup(vocabGroup, with: wordList)
        }

        if !displacedGroupIds.isEmpty {
            VocabGroupManager.shared.pruneEmptyGroups(with: wordList)
        }

        showSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveConfirmation = false
        }
    }

    private func generateExample() {
        chatViewModel.generateExampleSentence(for: preferredInputForExample()) { sentence in
            example = sentence
        }
    }

    /// Kanji > phonetic > english, mirroring `Word.displayText`'s fallback
    /// order but reading from the live form fields rather than a saved
    /// `Word` snapshot.
    private func preferredInputForExample() -> String {
        let trimmedKanji = kanji.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKanji.isEmpty { return trimmedKanji }
        let trimmedPhonetic = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPhonetic.isEmpty { return trimmedPhonetic }
        return english
    }
}

#Preview {
    AddWordView()
}
