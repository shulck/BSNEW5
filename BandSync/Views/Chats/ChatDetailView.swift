//
//  ChatDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ChatDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    @StateObject private var chatService = ChatService.shared
    @State private var messageText = ""
    @State private var replyTo: Message?

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chatService.messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                if let reply = message.replyTo,
                                   let original = chatService.messages.first(where: { $0.id == reply }) {
                                    Text("↪️ \(original.text)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                HStack {
                                    Text(message.text)
                                        .padding(8)
                                        .background(AppState.shared.user?.id == message.senderId ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    Spacer()
                                }

                                HStack {
                                    Button("Reply") {
                                        replyTo = message
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.blue)

                                    if message.senderId == AppState.shared.user?.id {
                                        Button("Edit") {
                                            messageText = message.text
                                        }
                                        .font(.caption2)

                                        Button("Delete") {
                                            chatService.deleteMessage(message)
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                    }
                                }
                            }
                            .id(message.id ?? UUID().uuidString)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: chatService.messages.count) { _ in
                    if let last = chatService.messages.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack {
                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    send()
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle(chat.name)
        .onAppear {
            chatService.fetchMessages(for: chat.id ?? "")
        }
    }

    private func send() {
        guard let userId = AppState.shared.user?.id,
              let chatId = chat.id else { return }

        let newMessage = Message(
            chatId: chatId,
            senderId: userId,
            text: messageText,
            timestamp: Date(),
            replyTo: replyTo?.id
        )

        chatService.sendMessage(newMessage)
        messageText = ""
        replyTo = nil
    }
}
