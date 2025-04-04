//
//  BandSyncApp.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import FirebaseCore

@main
struct BandSyncApp: App {
    // Register AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Don't call print() in the App struct initializer
        // This leads to compilation errors
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(AppState.shared)
                .onAppear {
                    print("SplashView: appeared")
                    // Ensure Firebase is already initialized
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("SplashView: launching deferred auth state update")
                        AppState.shared.refreshAuthState()
                    }
                }
        }
    }
}
