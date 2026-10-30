import SwiftUI

struct SampleSentencesView: View {
    @State private var sampleSentences: [Knowledge] = []
    @State private var sentenceText = ""
    @State private var noteText = ""
    @State private var isEditing = false
    @State private var selectedSentence: Knowledge?
    @State private var showComposer = false
    @State private var isBreakingDown = false
    @ObservedObject private var chatViewModel = ChatViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if sampleSentences.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.quote")
                                .font(.largeTitle)
                            Text("No sample sentences yet")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(sampleSentences.indices, id: \.self) { index in
                                let item = sampleSentences[index]
                                NavigationLink(destination: SampleSentenceDetailView(
                                    sample: Binding(
                                        get: { sampleSentences[index] },
                                        set: { sampleSentences[index] = $0 }
                                    ),
                                    onSave: { updated in
                                        sampleSentences[index] = updated
                                        saveSamples()
                                    },
                                    onDelete: {
                                        sampleSentences.remove(at: index)
                                        saveSamples()
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        let parsed = parseSentenceAndNote(from: item.text)
                                        Text(parsed.sentence)
                                            .font(.headline)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        let parsed = parseSentenceAndNote(from: item.text)
                                        sentenceText = parsed.sentence
                                        noteText = parsed.note
                                        selectedSentence = item
                                        isEditing = true
                                        showComposer = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                            }
                        }
                    }
                }

                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                sentenceText = ""
                                noteText = ""
                                selectedSentence = nil
                                isEditing = false
                                showComposer = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                            }
                            .padding()
                            .offset(x: -geometry.safeAreaInsets.trailing, y: -geometry.safeAreaInsets.bottom)
                        }
                    }
                }
            }
            .navigationTitle("Sample Sentences")
            .onAppear {
                loadSamples()
                chatViewModel.setup()
            }
            .sheet(isPresented: $showComposer) {
                NavigationStack {
                    Form {
                        Section(header: Text("Sentence")) {
                            TextField("Enter a sample sentence", text: $sentenceText, axis: .vertical)
                                .lineLimit(3...8)
                        }

                        Section(header: Text("Breakdown")) {
                            TextEditor(text: $noteText)
                                .frame(minHeight: 180)
                        }

                        Section {
                            HStack {
                                Button("Break down") {
                                    guard !sentenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                    isBreakingDown = true
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    chatViewModel.breakDownSentence(text: sentenceText) { response in
                                        DispatchQueue.main.async {
                                            noteText = response
                                            isBreakingDown = false
                                        }
                                    }
                                }
                                .disabled(sentenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBreakingDown)

                                if isBreakingDown {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                }
                            }
                        }
                    }
                    .navigationTitle(isEditing ? "Edit Sample" : "New Sample")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showComposer = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let trimmedSentence = sentenceText.trimmingCharacters(in: .whitespacesAndNewlines)
                                let trimmedNote = noteText.strippingMarkdown()
                                guard !trimmedSentence.isEmpty, !trimmedNote.isEmpty else { return }

                                let entry = Knowledge(id: selectedSentence?.id ?? UUID(), text: "Sentence: \(trimmedSentence)\n\nNote:\n\(trimmedNote)")
                                if let selected = selectedSentence {
                                    if let index = sampleSentences.firstIndex(where: { $0.id == selected.id }) {
                                        sampleSentences[index] = entry
                                    }
                                } else {
                                    sampleSentences.insert(entry, at: 0)
                                }

                                saveSamples()
                                showComposer = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadSamples() {
        sampleSentences = KnowledgeManager.shared.loadSampleSentences()
    }

    private func saveSamples() {
        KnowledgeManager.shared.saveSampleSentences(sampleSentences)
    }

    private func parseSentenceAndNote(from text: String) -> (sentence: String, note: String) {
        let lines = text.components(separatedBy: "\n")
        guard let sentenceLine = lines.first(where: { $0.hasPrefix("Sentence:") }) else {
            return (text, "")
        }

        let sentence = sentenceLine.replacingOccurrences(of: "Sentence:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let note = lines.drop(while: { !$0.hasPrefix("Note:") }).dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (sentence, note)
    }
}

struct SampleSentenceDetailView: View {
    @Binding var sample: Knowledge
    var onSave: ((Knowledge) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var editedSentence = ""
    @State private var editedNote = ""
    @State private var isEditingMode = false
    @State private var isBreakingDown = false
    @ObservedObject private var chatViewModel = ChatViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isEditingMode {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Sentence", text: $editedSentence, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...8)

                        TextEditor(text: $editedNote)
                            .frame(minHeight: 180)
                            .border(Color.secondary.opacity(0.3), width: 1)

                        HStack {
                            Button("Break down") {
                                guard !editedSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                isBreakingDown = true
                                chatViewModel.breakDownSentence(text: editedSentence) { response in
                                    DispatchQueue.main.async {
                                        editedNote = response
                                        isBreakingDown = false
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBreakingDown)

                            if isBreakingDown {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }

                        Button(role: .destructive) {
                            onDelete?()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } else {
                    Text(sample.text)
                        .font(.body)
                }
            }
            .padding()
        }
        .navigationTitle("Sample Sentence")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditingMode {
                    Button("Save") {
                        let trimmedSentence = editedSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNote = editedNote.strippingMarkdown()
                        guard !trimmedSentence.isEmpty, !trimmedNote.isEmpty else { return }

                        sample = Knowledge(id: sample.id, text: "Sentence: \(trimmedSentence)\n\nNote:\n\(trimmedNote)")
                        onSave?(sample)
                        isEditingMode = false
                    }
                } else {
                    Button("Edit") {
                        let parsed = parseSentenceAndNote(from: sample.text)
                        editedSentence = parsed.sentence
                        editedNote = parsed.note
                        isEditingMode = true
                    }
                }
            }
        }
        .onAppear {
            chatViewModel.setup()
            let parsed = parseSentenceAndNote(from: sample.text)
            editedSentence = parsed.sentence
            editedNote = parsed.note
        }
    }

    private func parseSentenceAndNote(from text: String) -> (sentence: String, note: String) {
        let lines = text.components(separatedBy: "\n")
        guard let sentenceLine = lines.first(where: { $0.hasPrefix("Sentence:") }) else {
            return (text, "")
        }

        let sentence = sentenceLine.replacingOccurrences(of: "Sentence:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let note = lines.drop(while: { !$0.hasPrefix("Note:") }).dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (sentence, note)
    }
}

#Preview {
    SampleSentencesView()
        .environmentObject(AuthViewModel())
}

