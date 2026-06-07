//
//  ChangePasswordView.swift
//  Japanese Assistant
//

import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordErrorMessage = ""
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var showIncorrectPasswordAlert = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        VStack {
            Text("Change Password")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 9)

            VStack(alignment: .leading, spacing: 9) {
                InputView(text: $currentPassword,
                          title: "Current Password",
                          placeholder: "Enter your current password",
                          isSecureField: true)

                VStack(alignment: .leading, spacing: 9) {
                    InputView(text: $newPassword,
                              title: "New Password",
                              placeholder: "At least 6 characters",
                              isSecureField: true)
                    .onChange(of: newPassword) {
                        validatePassword()
                    }

                    if !passwordErrorMessage.isEmpty {
                        Text(passwordErrorMessage)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .transition(.opacity)
                            .animation(.easeInOut, value: passwordErrorMessage)
                    }
                }

                ZStack(alignment: .trailing) {
                    InputView(text: $confirmPassword,
                              title: "Confirm New Password",
                              placeholder: "Re-enter your new password",
                              isSecureField: true)

                    if !newPassword.isEmpty && !confirmPassword.isEmpty {
                        if newPassword == confirmPassword {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemGreen))
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemRed))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 5)
            }

            Button {
                Task {
                    await changePassword()
                }
            } label: {
                HStack {
                    Text("Update Password")
                        .fontWeight(.semibold)
                    Image(systemName: "lock.rotation")
                }
                .foregroundColor(.white)
                .frame(width: UIScreen.main.bounds.width - 32, height: 48)
            }
            .background(Color(.systemBlue))
            .disabled(!formIsValid)
            .opacity(formIsValid ? 1.0 : 0.5)
            .cornerRadius(10)
            .padding(.top, 24)

            Spacer()
        }
        .padding()
        .alert("Incorrect Password", isPresented: $showIncorrectPasswordAlert, actions: {
            Button("Close", role: .cancel) {}
        }, message: {
            Text("Please try again.")
        })
        .alert("Password Updated", isPresented: $showSuccessAlert, actions: {
            Button("Close") { dismiss() }
        }, message: {
            Text("Your password has been updated successfully.")
        })
    }

    private func validatePassword() {
        if newPassword.isEmpty {
            passwordErrorMessage = ""
        } else if newPassword.count < 6 {
            passwordErrorMessage = "Password must be at least 6 characters."
        } else {
            passwordErrorMessage = ""
        }
    }

    private func changePassword() async {
        guard Auth.auth().currentUser != nil else {
            errorMessage = "You are not signed in."
            clearFields()
            return
        }

        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        do {
            try await viewModel.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            clearFields()
            showSuccessAlert = true
            errorMessage = ""
        } catch {
            clearFields()
            showIncorrectPasswordAlert = true
        }
    }

    private var formIsValid: Bool {
        return !currentPassword.isEmpty &&
               !newPassword.isEmpty &&
               !confirmPassword.isEmpty &&
               newPassword.count >= 6
    }

    private func clearFields() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(AuthViewModel())
}
