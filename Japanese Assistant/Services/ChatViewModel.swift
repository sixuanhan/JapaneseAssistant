import SwiftUI
import GoogleGenerativeAI

final class ChatViewModel: ObservableObject {
    private var client: GenerativeModel?

    init() {}

    func setup() {
        let apiKey = "AIzaSyB8rZ9slArRA6CeRp3BwvR6pjJQMoHiQp4"
        client = GenerativeModel(name: "gemini-1.5-flash-latest", apiKey: apiKey)
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
        Create a note for the user to explain the related idea or grammar. Be succinct. Explain in English. Use bullet points and headings, but no italics or bold. Always give examples. No need for intros and outros.
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
