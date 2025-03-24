import Foundation

class TranslationService {
    func translate(text: String, completion: @escaping (String?) -> Void) {
        // Replace with actual API call
        // For demonstration, we'll just return the input text appended with " (translated)"
        let translatedText = "\(text) (translated)"
        completion(translatedText)
    }
}