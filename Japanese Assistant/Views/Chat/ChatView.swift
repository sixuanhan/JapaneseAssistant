import SwiftUI

struct ChatView: View {
   @ObservedObject var viewModel = ChatViewModel()
   @State private var text = ""
   @State var userInput: String = ""
   @State var aiResponse: String = ""
   @State var knowledge: Knowledge?

   var body: some View {
       NavigationView {
           VStack {
               Spacer()

               ScrollView {
                   if !userInput.isEmpty {
                       ChatMessageView(message: self.userInput.trimmingCharacters(in: .whitespacesAndNewlines))
                   }

                   if aiResponse.isEmpty && !userInput.isEmpty {
                       ProgressView()
                           .padding(.horizontal)
                   } else if !aiResponse.isEmpty && !userInput.isEmpty {
                       KnowledgeCard(knowledge: Binding($knowledge)!)
                   }
               }

               Spacer()

               // Input Section
               HStack {
                   TextField("Ask anything...", text: $text)
                       .padding()
                       .background(Color.primary)
                       .cornerRadius(20)
                       .foregroundColor(Color(UIColor.systemBackground))
                       .frame(height: 50)

                   Button(action: send) {
                       Image(systemName: "paperplane.fill")
                           .resizable()
                           .frame(width: 24, height: 24)
                           .padding()
                           .background(Color.primary)
                           .foregroundColor(Color(UIColor.systemBackground))
                           .clipShape(Circle())
                           .shadow(radius: 5)
                   }
               }
               .padding()
           }
           .onAppear {
               viewModel.setup()
           }
       }
       .navigationTitle("Chat")
   }

   func send() {
       guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

       self.userInput = text

       let textToSend = self.text
       self.text = ""  // Clear input field

       // Hide the keyboard
       UIApplication.shared.endEditing()

       viewModel.send(text: textToSend) { response in
           DispatchQueue.main.async {
               self.aiResponse = parseMessage(response)
               self.knowledge = Knowledge(text: self.aiResponse)
           }
       }
   }

   private func hideKeyboard() {
       UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
   }

   private func parseMessage(_ text: String) -> String {
       var result = ""
       let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

       for line in lines {
           if line.starts(with: "# ") {
               // Heading: Remove `#` and add a newline
               let headingText = line.dropFirst(2)
               result += "\(headingText.uppercased())\n"
           } else if line.starts(with: "* ") {
               // List item: Replace `*` with `•`
               let listItemText = line.dropFirst(2)
               result += "• \(listItemText)\n"
           } else {
               // Normal text: Add as is
               result += "\(line)\n"
           }
       }

       return result.trimmingCharacters(in: .whitespacesAndNewlines)
   }
}

// Extension to hide the keyboard
extension UIApplication {
   func endEditing() {
       sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
   }
}

#Preview {
   ChatView()
   .preferredColorScheme(.dark)
}
