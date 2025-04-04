//
//  AddTaskView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  AddTaskView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var assignedTo = ""
    @State private var dueDate = Date()

    var body: some View {
        NavigationView {
            Form {
                TextField("Task name", text: $title)
                TextField("Description", text: $description)
                TextField("Assigned to (userID)", text: $assignedTo)
                DatePicker("Deadline", selection: $dueDate, displayedComponents: .date)
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.isEmpty || assignedTo.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        guard let groupId = AppState.shared.user?.groupId else { return }

        let task = TaskModel(
            title: title,
            description: description,
            assignedTo: assignedTo,
            dueDate: dueDate,
            completed: false,
            groupId: groupId
        )

        TaskService.shared.addTask(task) { success in
            if success { dismiss() }
        }
    }
}
