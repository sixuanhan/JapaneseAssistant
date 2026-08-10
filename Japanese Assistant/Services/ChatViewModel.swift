//
//  ChatViewModel.swift
//  Japanese Assistant
//
//  Wraps the Firebase AI (Gemini) client with a handful of prompt
//  helpers used across the app: Q&A, per-word example sentences,
//  vocab-group differentiation notes, and sentence break-downs.
//

import SwiftUI
import FirebaseAI

final class ChatViewModel: ObservableObject {
    private var client: GenerativeModel?

    /// Task tracking the pending vocab-group note request. New requests
    /// cancel any in-flight one so a burst of selection toggles collapses
    /// into a single billed Gemini call.
    private var vocabGroupNoteTask: Task<Void, Never>?
    private var vocabGroupNoteRequestID: UUID?
    private let vocabGroupNoteDebounceNanoseconds: UInt64 = 400_000_000

    init() {}

    func setup() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        client = ai.generativeModel(modelName: "gemini-2.5-flash-lite")
    }

    // MARK: - Public prompt methods

    func send(text: String, completion: @escaping (String) -> Void) {
        let prompt = """
        You are a Japanese teacher. Your student asks you the following question:
        "\(text)"
        Create a note for the user to explain the related idea or grammar. Be succinct. Explain in Chinese. For Japanese words or phrases, do not include Romajis. 
        Use bullet points and headings, but no italics or bold. Always give examples. No need for intros and outros.
        """
        run(prompt: prompt, completion: completion)
    }

    func generateExampleSentence(for word: String, completion: @escaping (String) -> Void) {
        let prompt = """
        You are a Japanese teacher. 
        Generate a very simple Japanese sentence using the word '\(word)' for your student. 
        Provide only the sentence, no explanation.
        """
        run(prompt: prompt, trim: true, completion: completion)
    }

    func breakDownSentence(text: String, completion: @escaping (String) -> Void) {
        let prompt = """
        You are a Japanese teacher. Your student asks you the break down the grammar of this sentence:
        "\(text)"
        Create a note for the user to explain the grammar, focus on sentence ordering, verbs, adjectives, and adverb transformation.
        Be succinct. Explain in Chinese. For Japanese words or phrases, do not include Romajis. Use bullet points.
        Sample format:
        翻译
        【句子的中文翻译】
        语法分析
        1. 【语法点1】
        2. 【语法点2】
        其他值得注意的知识点
        1. 【知识点1】
        2. 【知识点2】
        """
        run(prompt: prompt, completion: completion)
    }

    /// Generates a vocab-group differentiation note.
    ///
    /// Callers pass a `requestID` per invocation; each new call cancels
    /// any pending in-flight request and waits ~400 ms before firing the
    /// network call, so a burst of selection toggles collapses into a
    /// single billed Gemini request.
    func generateVocabGroupNote(for words: [Word], requestID: UUID, completion: @escaping (String) -> Void) {
        vocabGroupNoteTask?.cancel()
        vocabGroupNoteRequestID = requestID

        guard let client = client else {
            print("Error: Gemini client is not initialized.")
            completion("Error: Gemini client not initialized")
            return
        }

        let wordTexts = words.map { $0.displayText }
        let prompt = """
        You are an experienced Japanese teacher. Your student is asking you to differentiate between the following words: \(wordTexts.joined(separator: ", ")). 
        Create a note to explain. Be succinct. Explain in Chinese. Use bullet points and headings, but no italics or bold. 
        Always give examples. No need for intros and outros. Sample format:
        1. 【词语1】
        【解释】
        【例句】
        2. 【词语2】
        【解释】
        【例句】
        总结：【总结】
        """

        let debounce = vocabGroupNoteDebounceNanoseconds
        vocabGroupNoteTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: debounce)
            } catch {
                return // cancelled during debounce
            }
            guard !Task.isCancelled else { return }

            do {
                let response = try await client.generateContent(prompt)
                guard !Task.isCancelled,
                      self?.vocabGroupNoteRequestID == requestID else { return }
                if let output = response.text, !output.isEmpty {
                    let cleaned = output.strippingMarkdown()
                    DispatchQueue.main.async {
                        completion(cleaned)
                    }
                } else {
                    print("Warning: API returned an empty response.")
                    DispatchQueue.main.async {
                        completion("Error: No response from API")
                    }
                }
            } catch is CancellationError {
                // Superseded by a newer request — drop silently.
                return
            } catch {
                guard !Task.isCancelled,
                      self?.vocabGroupNoteRequestID == requestID else { return }
                print("API request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Shared plumbing

    /// Fires a single Gemini request and dispatches the completion on
    /// the main queue. `trim` strips surrounding whitespace / newlines
    /// from the response (used for short single-sentence outputs).
    private func run(prompt: String, trim: Bool = false, completion: @escaping (String) -> Void) {
        guard let client = client else {
            print("Error: Gemini client is not initialized.")
            completion("Error: Gemini client not initialized")
            return
        }
        Task {
            do {
                let response = try await client.generateContent(prompt)
                if let output = response.text, !output.isEmpty {
                    let stripped = output.strippingMarkdown()
                    let value = trim ? stripped.trimmingCharacters(in: .whitespacesAndNewlines) : stripped
                    DispatchQueue.main.async {
                        completion(value)
                    }
                } else {
                    print("Warning: API returned an empty response.")
                    DispatchQueue.main.async {
                        completion("Error: No response from API")
                    }
                }
            } catch {
                print("API request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion("Error: \(error.localizedDescription)")
                }
            }
        }
    }
}
