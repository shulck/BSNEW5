//
//  GroupSelectionView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  GroupSelectionView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI

struct GroupSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "music.mic")
                .resizable()
                .frame(width: 80, height: 80)
                .padding()
            
            Text("Welcome to BandSync!")
                .font(.title.bold())
            
            Text("To get started, create a new group or join an existing one")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                Button(action: {
                    showCreateGroup = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create new group")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    showJoinGroup = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join a group")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button("Log out") {
                appState.logout()
            }
            .padding(.bottom, 20)
        }
        .padding()
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView()
        }
        .sheet(isPresented: $showJoinGroup) {
            JoinGroupView()
        }
    }
}