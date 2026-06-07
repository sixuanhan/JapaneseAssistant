//
//  SettingsRowView.swift
//  Japanese Assistant
//

import SwiftUI

struct SettingsRowView: View {
    let imageName: String
    let title: String
    let tintColor: Color
    let textColor: Color

    init(imageName: String, title: String, tintColor: Color = Color(.systemGray), textColor: Color = Color(.label)) {
        self.imageName = imageName
        self.title = title
        self.tintColor = tintColor
        self.textColor = textColor
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: imageName)
                .imageScale(.small)
                .font(.title)
                .foregroundColor(tintColor)

            Text(title)
                .font(.subheadline)
                .foregroundColor(textColor)
        }
    }
}

#Preview {
    SettingsRowView(imageName: "gear", title: "Version")
}
