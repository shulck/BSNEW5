//
//  AuthService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {
    static let shared = AuthService()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private init() {
        print("AuthService: initialized")
    }
    
    func registerUser(email: String, password: String, name: String, phone: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: starting user registration with email \(email)")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                print("AuthService: error creating user: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let uid = result?.user.uid else {
                print("AuthService: UID missing after user creation")
                completion(.failure(NSError(domain: "UIDMissing", code: -1, userInfo: nil)))
                return
            }
            
            print("AuthService: user created with UID: \(uid)")

            let userData: [String: Any] = [
                "id": uid,
                "email": email,
                "name": name,
                "phone": phone,
                "groupId": NSNull(),
                "role": "Member"
            ]
            
            print("AuthService: saving user data: \(userData)")

            self?.db.collection("users").document(uid).setData(userData) { error in
                if let error = error {
                    print("AuthService: error saving user data: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("AuthService: user data successfully saved")
                    completion(.success(()))
                }
            }
        }
    }

    func loginUser(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: attempting to log in user with email \(email)")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        auth.signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                print("AuthService: error logging in: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("AuthService: user login successful")
                completion(.success(()))
            }
        }
    }

    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: sending password reset request for email \(email)")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        auth.sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("AuthService: error resetting password: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("AuthService: password reset request sent successfully")
                completion(.success(()))
            }
        }
    }

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: attempting to log out user")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        do {
            try auth.signOut()
            print("AuthService: user logout successful")
            completion(.success(()))
        } catch {
            print("AuthService: error logging out: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    func isUserLoggedIn() -> Bool {
        print("AuthService: checking user authorization")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        let isLoggedIn = auth.currentUser != nil
        print("AuthService: user is \(isLoggedIn ? "authorized" : "not authorized")")
        return isLoggedIn
    }

    func currentUserUID() -> String? {
        print("AuthService: requesting current user UID")
        
        // Make sure Firebase is initialized
        FirebaseManager.shared.ensureInitialized()
        
        let uid = auth.currentUser?.uid
        print("AuthService: current user UID: \(uid ?? "missing")")
        return uid
    }
}
