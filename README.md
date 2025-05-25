# README: Japanese Assistant

## Overview

Japanese Assistant is a Swift-based iOS application designed to help users learn and manage Japanese language concepts. The app provides features such as chat-based AI assistance, knowledge card management, vocabulary flashcards, and integration with external resources for enhanced learning.

## Updates

The Google Generative AI API has been deprecated recently. New modifications aim to resolve this issue.

## Features

1. **Chat with AI:**
    Ask questions about Japanese grammar, vocabulary, or culture. Receive detailed, structured responses from an AI-powered assistant.
2. **Knowledge Cards:**
    Save AI responses as editable knowledge cards. Organize and manage knowledge cards for future reference. Edit and save changes to knowledge cards dynamically.
3. **Collect and Manage Vocabularies:**
    CRUD, sort, and filter your vocabularies in the "List" tab. Click on them to listen, and search for more details in "Edit".
4. **Practice Vocabularies:**
   Use Anki-style vocabulary memorization technique to refresh your memory in the "Practice" tab.
5. **Translation:**
   Translate between English and Japanese instantly. Copy paste or listen to them.

## Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/sixuanhan/JapaneseAssistant.git
    ```

2. Open the project in Xcode.
3. Ensure you have the latest version of Xcode and Swift installed.
4. Change your team and bundle ID to a unique bundle ID under "Signing and Capabilities" in XCode.
   ![Signing and Capabilities](/Japanese%20Assistant/Images/signing.png)
5. Run the app on a simulator or a connected iOS device.

## Dependencies

- SwiftUI: For building the user interface.
- GoogleGenerativeAI: For AI-powered chat functionality. Replace API key in `ChatViewModel`. Get an API key [here](https://aistudio.google.com/app/u/1/apikey?_gl=1*13i7v9c*_ga*MTkxNDA5NzIyMi4xNzM5MjQyMjY5*_ga_P1DBVKWT6V*MTc0NjIxNjcxNy40LjAuMTc0NjIxNjcxOC41OS4wLjY2ODIyNTYzNQ..).
- DeepL: For translation. Replace API key in `TranslationService`. Get an API key [here](https://www.deepl.com/en/pro-api?utm_term=&utm_campaign=US%7CPMAX%7CC%7CEnglish&utm_source=google&utm_medium=paid&hsa_acc=1083354268&hsa_cam=21607908173&hsa_grp=&hsa_ad=&hsa_src=x&hsa_tgt=&hsa_kw=&hsa_mt=&hsa_net=adwords&hsa_ver=3&gad_source=1&gad_campaignid=21601196877&gbraid=0AAAAABbqoWDqz0tCSD0Yxn1Cz8U8rNjvu&gclid=Cj0KCQjw2tHABhCiARIsANZzDWoBescJx2hzrKI_Q0zYkHSI3fecNC0P_Ux-u3WODBp4KsRJ8JnNXn4aAtZzEALw_wcB#api-pricing).
- kanjiAlive: For translating Kanji to Hiragana. Replace API key in `TranslationService`. Get an API key [here](https://app.kanjialive.com/api/docs).

## Known Issues

- Since there is no perfect sentence-in-kanji-to-sentence-in-hiragana translating API, the app uses kanjiAlive to translate each Kanji to Hiragana when adding a word. It is rarely accurate, so please always check the Hiragana to make sure it is correct.

## Future Enhancements

- Moving database from UserDefault to a cloud database.
- Add support for exporting knowledge cards as PDFs or text files.
- Integrate directly with Duolingo.

## Contributing

1. Fork the repository.
2. Create a new branch for your feature or bug fix:

   ```bash
   git checkout -b feature-name
   ```

3. Commit your changes:

   ```bash
   git commit -m "Add feature-name"
   ```

4. Push to your branch:

    ```bash
    git push origin feature-name
    ```

5. Submit a pull request.
