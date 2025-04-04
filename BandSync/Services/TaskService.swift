//
//  TaskService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  TaskService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class TaskService: ObservableObject {
    static let shared = TaskService()

    @Published var tasks: [TaskModel] = []

    private let db = Firestore.firestore()

    func fetchTasks(for groupId: String) {
        db.collection("tasks")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "dueDate")
            .addSnapshotListener { snapshot, _ in
                if let docs = snapshot?.documents {
                    let tasks = docs.compactMap { try? $0.data(as: TaskModel.self) }
                    DispatchQueue.main.async {
                        self.tasks = tasks
                    }
                }
            }
    }

    func addTask(_ task: TaskModel, completion: @escaping (Bool) -> Void) {
        do {
            _ = try db.collection("tasks").addDocument(from: task) { error in
                completion(error == nil)
            }
        } catch {
            completion(false)
        }
    }

    func toggleCompletion(_ task: TaskModel) {
        guard let id = task.id else { return }
        db.collection("tasks").document(id).updateData([
            "completed": !task.completed
        ])
    }

    func deleteTask(_ task: TaskModel) {
        guard let id = task.id else { return }
        db.collection("tasks").document(id).delete()
    }
}
