//
//  AuthViewModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var phone = ""
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login() {
        isLoading = true
        AuthService.shared.loginUser(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.isAuthenticated = true
                    // Add global state update
                    AppState.shared.refreshAuthState()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func register() {
        isLoading = true
        AuthService.shared.registerUser(email: email, password: password, name: name, phone: phone) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.isAuthenticated = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func resetPassword() {
        isLoading = true
        AuthService.shared.resetPassword(email: email) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.errorMessage = "Password reset email sent"
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
