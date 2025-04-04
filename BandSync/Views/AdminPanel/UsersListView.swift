//
//  UsersListView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct UsersListView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var showingRoleView = false
    @State private var selectedUserId = ""
    
    var body: some View {
        List {
            if groupService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                // Group members
                if !groupService.groupMembers.isEmpty {
                    Section(header: Text("Members")) {
                        ForEach(groupService.groupMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("Role: \(user.role.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Action buttons
                                if user.id != AppState.shared.user?.id {
                                    Menu {
                                        Button("Change role") {
                                            selectedUserId = user.id
                                            showingRoleView = true
                                        }
                                        
                                        Button("Remove from group", role: .destructive) {
                                            groupService.removeUser(userId: user.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Pending approvals
                if !groupService.pendingMembers.isEmpty {
                    Section(header: Text("Awaiting approval")) {
                        ForEach(groupService.pendingMembers) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Accept/reject buttons
                                Button {
                                    groupService.approveUser(userId: user.id)
                                } label: {
                                    Text("Accept")
                                        .foregroundColor(.green)
                                }
                                
                                Button {
                                    groupService.rejectUser(userId: user.id)
                                } label: {
                                    Text("Decline")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                // Invitation code
                if let group = groupService.group {
                    Section(header: Text("Invitation code")) {
                        HStack {
                            Text(group.code)
                                .font(.system(.title3, design: .monospaced))
                                .bold()
                            
                            Spacer()
                            
                            Button {
                                UIPasteboard.general.string = group.code
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                        
                        Button("Generate new code") {
                            groupService.regenerateCode()
                        }
                    }
                }
            }
            
            if let error = groupService.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Group members")
        .onAppear {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
            }
        }
        .sheet(isPresented: $showingRoleView) {
            RoleSelectionView(userId: selectedUserId)
        }
        .refreshable {
            if let gid = AppState.shared.user?.groupId {
                groupService.fetchGroup(by: gid)
            }
        }
    }
}

// Role selection view
struct RoleSelectionView: View {
    let userId: String
    @StateObject private var groupService = GroupService.shared
    @State private var selectedRole: UserModel.UserRole = .member
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select a role")) {
                    ForEach(UserModel.UserRole.allCases, id: \.self) { role in
                        Button {
                            selectedRole = role
                            groupService.changeUserRole(userId: userId, newRole: role)
                            dismiss()
                        } label: {
                            HStack {
                                Text(role.rawValue)
                                Spacer()
                                if selectedRole == role {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                if groupService.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                
                if let error = groupService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Change role")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Try to find the user's current role
            if let user = groupService.groupMembers.first(where: { $0.id == userId }) {
                selectedRole = user.role
            }
        }
    }
}
