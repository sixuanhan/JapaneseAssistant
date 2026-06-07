//
//  ContentView.swift
//  Japanese Assistant
//
//  Routes between the sign-in screen and the main app shell
//  based on the current Firebase auth session.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        Group {
            if viewModel.userSession != nil {
                AppView()
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
