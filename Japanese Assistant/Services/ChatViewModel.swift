import SwiftUI
import FirebaseAI

final class ChatViewModel: ObservableObject {
   private var client: GenerativeModel?

   init() {}

   func setup() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        client = ai.generativeModel(modelName: "gemini-2.5-flash-lite")
   }

   func send(text: String, completion: @escaping (String) -> Void) {
       guard let client = client else {
           print("Error: Gemini client is not initialized.")
           completion("Error: Gemini client not initialized")
           return
       }

       // Wrap the user's input in the custom prompt
       let prompt = """
       You are a Japanese teacher. Your student asks you the following question:
       "\(text)"
       Create a note for the user to explain the related idea or grammar. Be succinct. Explain in English. For Japanese words or phrases, do not include Romajis. 
       Use bullet points and headings, but no italics or bold. Always give examples. No need for intros and outros.
       """

       Task {
           do {
               let response = try await client.generateContent(prompt)
               if let output = response.text, !output.isEmpty {
                   DispatchQueue.main.async {
                       completion(output)
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

   func generateExampleSentence(for word: String, completion: @escaping (String) -> Void) {
       guard let client = client else {
           print("Error: Gemini client is not initialized.")
           completion("Error: Gemini client not initialized")
           return
       }

       let prompt = """
       You are a Japanese teacher. 
       Generate a very simple Japanese sentence using the word '\(word)' for your student. 
       Provide only the sentence, no explanation.
       """

       Task {
           do {
               let response = try await client.generateContent(prompt)
               if let output = response.text, !output.isEmpty {
                   DispatchQueue.main.async {
                       completion(output.trimmingCharacters(in: .whitespacesAndNewlines))
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

   func breakDownSentence(text: String, completion: @escaping (String) -> Void) {
       guard let client = client else {
           print("Error: Gemini client is not initialized.")
           completion("Error: Gemini client not initialized")
           return
       }

       let prompt = """
       You are a Japanese teacher. Your student asks you the break down the grammar of this sentence:
       "\(text)"
       Create a note for the user to explain the grammar, focus on sentence ordering, verbs, adjectives, and adverb transformation.
       Be succinct. Explain in English. For Japanese words or phrases, do not include Romajis. 
       Use bullet points and headings, but no italics or bold. No need for intros and outros.
       """

       Task {
           do {
               let response = try await client.generateContent(prompt)
               if let output = response.text, !output.isEmpty {
                   DispatchQueue.main.async {
                       completion(output)
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