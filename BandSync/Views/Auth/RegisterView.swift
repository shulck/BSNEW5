//
//  RegisterView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Registration")
                    .font(.title.bold())
                    .padding(.top)

                TextField("Name", text: $viewModel.name)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)

                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)

                TextField("Phone", text: $viewModel.phone)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)

                Button("Register") {
                    viewModel.register()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.name.isEmpty)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
    }
}
