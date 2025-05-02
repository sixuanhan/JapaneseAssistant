import SwiftUI

struct ChatMessageView: View {
    let message: String
    
    var body: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 10)
            ChatBubbleView(message: message)
            Image(uiImage: UIImage(systemName: "person.crop.circle.fill")!)
                .resizable()
                .frame(width: 45, height: 45)
                .clipShape(Circle())
                .foregroundColor(.blue)
                .overlay(Circle().stroke(Color.black, lineWidth: 1))
        }
        .padding(.horizontal, 5)
        
    }
}

#Preview {
    VStack {
        ChatMessageView(message: "I need some assistance with my account.")
    }
}
