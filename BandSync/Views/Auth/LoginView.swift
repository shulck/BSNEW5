//
//  LoginView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("BandSync")
                    .font(.largeTitle.bold())
                    .padding(.top)

                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)

                Button("Login") {
                    viewModel.login()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty)

                Button("Login with Face ID") {
                    authenticateWithFaceID()
                }

                Button("Forgot password?") {
                    showForgotPassword = true
                }
                .padding(.top, 5)

                NavigationLink("Registration", destination: RegisterView())
                    .padding(.top)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Login")
            .fullScreenCover(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }

    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Login with Face ID") { success, error in
                if success {
                    DispatchQueue.main.async {
                        viewModel.isAuthenticated = true
                    }
                } else {
                    DispatchQueue.main.async {
                        viewModel.errorMessage = "Face ID error"
                    }
                }
            }
        } else {
            viewModel.errorMessage = "Face ID not available"
        }
    }
}
