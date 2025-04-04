//
//  TaskModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  TaskModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore

struct TaskModel: Identifiable, Codable {
    @DocumentID var id: String?

    var title: String
    var description: String
    var assignedTo: String
    var dueDate: Date
    var completed: Bool
    var groupId: String
}
