import Foundation

class TranslationService {
    private let deepLApiKey = "" // Replace with your DeepL API key
    private let deepLApiUrl = "https://api-free.deepl.com/v2/translate"
    private let kanjiAliveApiKey = "" // Replace with your Kanji Alive API key
    private let kanjiAliveApiUrl = "https://kanjialive-api.p.rapidapi.com/api/public/kanji/"

    func translate(text: String, completion: @escaping (Word?) -> Void) {
        guard let url = URL(string: deepLApiUrl) else {
            print("Error: Invalid DeepL API URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(deepLApiKey)", forHTTPHeaderField: "Authorization")

        // Detect if the input is Japanese or English
        let isInputJapanese = JapaneseIdentifier.shared.isJapanese(text)
        let sourceLang = isInputJapanese ? "JA" : "EN"
        let targetLang = isInputJapanese ? "EN" : "JA"

        // Prepare the request body
        let requestBody: [String: Any] = [
            "text": [text],
            "source_lang": sourceLang,
            "target_lang": targetLang
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        // Perform the DeepL API request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("Error: No data received from DeepL API")
                completion(nil)
                return
            }

            do {
                // Parse the DeepL API response
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                // print("DeepL API Response: \(json ?? [:])")

                if let translations = json?["translations"] as? [[String: Any]],
                   let firstTranslation = translations.first,
                   let translatedText = firstTranslation["text"] as? String {
                    
                    var phonetic = ""
                    var kanji = ""
                    var english = ""

                    if isInputJapanese {
                        if JapaneseIdentifier.shared.isKanji(text) {
                            kanji = text
                            english = translatedText
                        } else {
                            phonetic = text
                            english = translatedText
                        }
                    } else {
                        if JapaneseIdentifier.shared.isKanji(translatedText) {
                            kanji = translatedText
                            english = text
                        } else {
                            phonetic = translatedText
                            english = text
                        }
                    }

                    if phonetic.isEmpty {
                        self.kanjiToPhonetic(kanji) { phonetic in
                            let word = Word(
                                id: UUID(),
                                Phonetic: phonetic ?? "",
                                Kanji: kanji,
                                English: english,
                                example: "",
                                nextDueDate: Date()
                            )
                            completion(word)
                        }
                    } else {
                        let word = Word(
                            id: UUID(),
                            Phonetic: phonetic,
                            Kanji: kanji,
                            English: english,
                            example: "",
                            nextDueDate: Date()
                        )
                        completion(word)
                    }
                } else {
                    print("Error: Unexpected response format from DeepL API")
                    completion(nil)
                }
            } catch {
                print("Error parsing DeepL API response: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }

    // Fetch phonetic (hiragana) for kanji using Kanji Alive API
    private func fetchKanjiPhonetic(for kanji: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(kanjiAliveApiUrl)\(kanji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")") else {
            print("Error: Invalid Kanji Alive API URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(kanjiAliveApiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("kanjialive-api.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("Error: No data received from Kanji Alive API")
                completion(nil)
                return
            }

            do {
                // Parse the Kanji Alive API response
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                // print("Kanji Alive API Response: \(json ?? [:])")

                if let kanjiInfo = json?["kanji"] as? [String: Any],
                let kunyomi = kanjiInfo["kunyomi"] as? [String: Any],
                let hiragana = kunyomi["hiragana"] as? String {
                    completion(hiragana) // Return the hiragana from kunyomi
                } else {
                    print("Error: Unexpected response format from Kanji Alive API")
                    completion(nil)
                }
            } catch {
                print("Error parsing Kanji Alive API response: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }

    private func kanjiToPhonetic(_ text: String, completion: @escaping (String) -> Void) {
        // Regular expression to match kanji characters
        let kanjiRegex = "\\p{Han}"
        var phoneticResult = text // Start with the original text
        var kanjiToPhoneticMap: [String: String] = [:] // Cache for kanji-to-phonetic mappings
        let kanjiCharacters = text.compactMap { char -> String? in
            let scalar = String(char)
            return scalar.range(of: kanjiRegex, options: .regularExpression) != nil ? scalar : nil
        }

        // If no kanji characters are found, return the original text
        guard !kanjiCharacters.isEmpty else {
            completion(text)
            return
        }

        // Dispatch group to handle asynchronous fetches for all kanji
        let dispatchGroup = DispatchGroup()

        for kanji in kanjiCharacters {
            // Avoid duplicate API calls for the same kanji
            if kanjiToPhoneticMap[kanji] == nil {
                dispatchGroup.enter()
                fetchKanjiPhonetic(for: kanji) { phonetic in
                    if let phonetic = phonetic {
                        kanjiToPhoneticMap[kanji] = phonetic
                    } else {
                        kanjiToPhoneticMap[kanji] = kanji // Fallback to the kanji itself if no phonetic is found
                    }
                    dispatchGroup.leave()
                }
            }
        }

        // Once all kanji have been processed, reconstruct the string
        dispatchGroup.notify(queue: .main) {
            for (kanji, phonetic) in kanjiToPhoneticMap {
                phoneticResult = phoneticResult.replacingOccurrences(of: kanji, with: phonetic)
            }
            completion(phoneticResult)
        }
    }

    func simpleTranslate(text: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: deepLApiUrl) else {
            print("Error: Invalid DeepL API URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(deepLApiKey)", forHTTPHeaderField: "Authorization")

        // Detect if the input is Japanese or English
        let isInputJapanese = JapaneseIdentifier.shared.isJapanese(text)
        let sourceLang = isInputJapanese ? "JA" : "EN"
        let targetLang = isInputJapanese ? "EN" : "JA"

        // Prepare the request body
        let requestBody: [String: Any] = [
            "text": [text],
            "source_lang": sourceLang,
            "target_lang": targetLang
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        // Perform the DeepL API request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("Error: No data received from DeepL API")
                completion(nil)
                return
            }

            do {
                // Parse the DeepL API response
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                // print("DeepL API Response: \(json ?? [:])")

                if let translations = json?["translations"] as? [[String: Any]],
                   let firstTranslation = translations.first,
                   let translatedText = firstTranslation["text"] as? String {  
                    completion(translatedText)
                } else {
                    print("Error: Unexpected response format from DeepL API")
                    completion(nil)
                }
            } catch {
                print("Error parsing DeepL API response: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }
}
