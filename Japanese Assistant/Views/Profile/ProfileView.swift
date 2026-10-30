//
//  ProfileView.swift
//  Japanese Assistant
//

import SwiftUI

struct ProfileView: View {
    @State private var showDeleteAccountAlert = false
    @State private var showSignOutAlert = false
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        NavigationView {
            if let user = viewModel.currentUser {
                Form {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(user.username)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    Section("Stats") {
                        HStack {
                            Text("Words")
                            Spacer()
                            Text("\(user.wordBank.count)")
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Knowledge Cards")
                            Spacer()
                            Text("\(user.knowledgeCards.count)")
                                .foregroundColor(.gray)
                        }
                    }

                    Section("Account") {
                        NavigationLink(destination: ChangePasswordView()) {
                            SettingsRowView(imageName: "key.fill",
                                            title: "Change Password",
                                            textColor: .primary)
                        }

                        Button {
                            showSignOutAlert = true
                        } label: {
                            SettingsRowView(imageName: "arrow.left.circle.fill",
                                            title: "Sign Out",
                                            textColor: .primary)
                        }
                        .alert(isPresented: $showSignOutAlert) {
                            Alert(
                                title: Text("Sign Out"),
                                message: Text("Are you sure you want to sign out?"),
                                primaryButton: .destructive(Text("Sign Out")) {
                                    viewModel.signOut()
                                },
                                secondaryButton: .cancel()
                            )
                        }

                        Button {
                            showDeleteAccountAlert = true
                        } label: {
                            SettingsRowView(imageName: "xmark.circle.fill",
                                            title: "Delete Account",
                                            tintColor: .red,
                                            textColor: .red)
                        }
                        .alert(isPresented: $showDeleteAccountAlert) {
                            Alert(
                                title: Text("Delete Account"),
                                message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                                primaryButton: .destructive(Text("Delete")) {
                                    viewModel.deleteAccount()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                }
                .navigationBarTitle("Profile")
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
