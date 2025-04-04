//
//  ChatService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  ChatService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class ChatService: ObservableObject {
    static let shared = ChatService()
    private let db = Firestore.firestore()

    @Published var chats: [Chat] = []
    @Published var messages: [Message] = []

    func fetchChats(for userId: String) {
        db.collection("chats")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, _ in
                if let docs = snapshot?.documents {
                    let result = docs.compactMap { try? $0.data(as: Chat.self) }
                    DispatchQueue.main.async {
                        self.chats = result
                    }
                }
            }
    }

    func fetchMessages(for chatId: String) {
        db.collection("messages")
            .whereField("chatId", isEqualTo: chatId)
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, _ in
                if let docs = snapshot?.documents {
                    let result = docs.compactMap { try? $0.data(as: Message.self) }
                    DispatchQueue.main.async {
                        self.messages = result
                    }
                }
            }
    }

    func sendMessage(_ message: Message) {
        do {
            _ = try db.collection("messages").addDocument(from: message)
            db.collection("chats").document(message.chatId).updateData([
                "lastMessage": message.text,
                "lastMessageTime": message.timestamp
            ])
        } catch {
            print("Error sending message: \(error)")
        }
    }

    func createChat(name: String, type: ChatType, participants: [String], completion: @escaping (Bool) -> Void) {
        let chat = Chat(name: name, type: type, participants: participants, lastMessage: nil, lastMessageTime: nil)
        do {
            _ = try db.collection("chats").addDocument(from: chat) { error in
                completion(error == nil)
            }
        } catch {
            completion(false)
        }
    }

    func deleteMessage(_ message: Message) {
        guard let id = message.id else { return }
        db.collection("messages").document(id).delete()
    }

    func editMessage(_ message: Message, newText: String) {
        guard let id = message.id else { return }
        db.collection("messages").document(id).updateData(["text": newText])
    }
}
