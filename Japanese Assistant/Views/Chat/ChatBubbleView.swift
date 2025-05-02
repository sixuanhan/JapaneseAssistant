import SwiftUI

struct ChatBubbleView: View {
    let message: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(message)
            .padding(12)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 4)
            .listRowSeparator(.hidden)
            .overlay(
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.footnote)
                    .rotationEffect(.degrees(-45))
                    .offset(x: 4, y: 5)
                    .foregroundColor(.blue),
                alignment: .bottomTrailing
            )
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}


#Preview {
    VStack {
        ChatBubbleView(message: """
        # Heading Example
        This is a normal text.
        - List item 1
        - List item 2
        **Bold text example**
        _Italic text example_
        """)
    }
}
