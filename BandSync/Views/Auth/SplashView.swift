//
//  SplashView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        if isActive {
            ContentView()
        } else {
            VStack {
                Image(systemName: "music.mic")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .padding()
                Text("BandSync")
                    .font(.largeTitle.bold())
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    isActive = true
                }
            }
        }
    }
}
