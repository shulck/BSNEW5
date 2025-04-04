//
//  ChatsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ChatsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct ChatsView: View {
    @StateObject private var chatService = ChatService.shared
    @State private var showNewChat = false

    var body: some View {
        NavigationView {
            List {
                ForEach(chatService.chats) { chat in
                    NavigationLink(destination: ChatDetailView(chat: chat)) {
                        VStack(alignment: .leading) {
                            Text(chat.name)
                                .font(.headline)
                            if let last = chat.lastMessage {
                                Text(last)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                Button {
                    showNewChat = true
                } label: {
                    Label("New chat", systemImage: "plus.bubble")
                }
            }
            .onAppear {
                if let userId = AppState.shared.user?.id {
                    chatService.fetchChats(for: userId)
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
        }
    }
}
