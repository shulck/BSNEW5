//
//  GroupActivityView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 04.04.2025.
//


//
//  GroupActivityView.swift
//  BandSync
//
//  Created by Claude AI on 04.04.2025.
//

import SwiftUI
import FirebaseFirestore

struct GroupActivityView: View {
    @StateObject private var viewModel = GroupActivityViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Заголовок и информация о группе
                GroupHeaderCard(group: viewModel.group)
                
                // Статистика активности
                if !viewModel.isLoading {
                    ActivityStatsView(stats: viewModel.stats)
                }
                
                // Последние события
                if !viewModel.recentEvents.isEmpty {
                    RecentActivitySection(
                        title: "Недавние события",
                        icon: "calendar",
                        items: viewModel.recentEvents.map { event in
                            ActivityItem(
                                title: event.title,
                                subtitle: formatDate(event.date),
                                icon: event.type.icon,
                                color: event.typeColor
                            )
                        }
                    )
                }
                
                // Последние сетлисты
                if !viewModel.recentSetlists.isEmpty {
                    RecentActivitySection(
                        title: "Недавние сетлисты",
                        icon: "music.note.list",
                        items: viewModel.recentSetlists.map { setlist in
                            ActivityItem(
                                title: setlist.name,
                                subtitle: "Песен: \(setlist.songs.count) • \(setlist.formattedTotalDuration)",
                                icon: "music.note",
                                color: .blue
                            )
                        }
                    )
                }
                
                // Задачи
                if !viewModel.pendingTasks.isEmpty {
                    RecentActivitySection(
                        title: "Незавершенные задачи",
                        icon: "checklist",
                        items: viewModel.pendingTasks.map { task in
                            ActivityItem(
                                title: task.title,
                                subtitle: "До \(formatDate(task.dueDate))",
                                icon: "checkmark.circle",
                                color: task.dueDate < Date() ? .red : .orange
                            )
                        }
                    )
                }
                
                // Недавние добавления участников
                if !viewModel.recentMembers.isEmpty {
                    RecentActivitySection(
                        title: "Новые участники",
                        icon: "person.3",
                        items: viewModel.recentMembers.map { member in
                            ActivityItem(
                                title: member.name,
                                subtitle: member.role.rawValue,
                                icon: "person.fill",
                                color: .green
                            )
                        }
                    )
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Активность группы")
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            viewModel.loadData()
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Вспомогательные представления

struct GroupHeaderCard: View {
    let group: GroupModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.mic")
                    .font(.title)
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(group?.name ?? "Загрузка...")
                        .font(.title2.bold())
                    if let createdAt = group?.createdAt {
                        Text("Создана \(formatDate(createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: GroupDetailView()) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ActivityStatsView: View {
    let stats: GroupActivityViewModel.ActivityStats
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Статистика")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 15) {
                StatBox(
                    value: stats.eventCount,
                    label: "События",
                    icon: "calendar",
                    color: .blue
                )
                
                StatBox(
                    value: stats.setlistCount,
                    label: "Сетлисты",
                    icon: "music.note.list",
                    color: .purple
                )
                
                StatBox(
                    value: stats.taskCount,
                    label: "Задачи",
                    icon: "checklist",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .padding(8)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            Text("\(value)")
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.5))
        .cornerRadius(8)
    }
}

struct RecentActivitySection: View {
    let title: String
    let icon: String
    let items: [ActivityItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(items) { item in
                ActivityItemView(item: item)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct ActivityItemView: View {
    let item: ActivityItem
    
    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .foregroundColor(item.color)
                .padding(8)
                .background(item.color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.subheadline.bold())
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel для экрана активности группы

class GroupActivityViewModel: ObservableObject {
    @Published var group: GroupModel?
    @Published var recentEvents: [Event] = []
    @Published var recentSetlists: [Setlist] = []
    @Published var pendingTasks: [TaskModel] = []
    @Published var recentMembers: [UserModel] = []
    @Published var stats = ActivityStats()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    struct ActivityStats {
        var eventCount: Int = 0
        var setlistCount: Int = 0
        var taskCount: Int = 0
        var memberCount: Int = 0
    }
    
    private let db = Firestore.firestore()
    
    func loadData() {
        guard let groupId = AppState.shared.user?.groupId else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Загрузка информации о группе
        db.collection("groups").document(groupId).getDocument { [weak self] snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Ошибка загрузки группы: \(error.localizedDescription)"
                    self?.isLoading = false
                }
                return
            }
            
            if let group = try? snapshot?.data(as: GroupModel.self) {
                DispatchQueue.main.async {
                    self?.group = group
                    // Обновляем счетчик участников
                    self?.stats.memberCount = group.members.count
                }
            }
            
            // Загружаем недавние события
            self?.loadRecentEvents(groupId)
        }
    }
    
    // Загрузка недавних событий
    private func loadRecentEvents(_ groupId: String) {
        db.collection("events")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "date", descending: true)
            .limit(to: 5)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let events = docs.compactMap { try? $0.data(as: Event.self) }
                    
                    DispatchQueue.main.async {
                        self?.recentEvents = events
                        self?.stats.eventCount = events.count
                        
                        // Загружаем сетлисты
                        self?.loadRecentSetlists(groupId)
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.loadRecentSetlists(groupId)
                    }
                }
            }
    }
    
    // Загрузка недавних сетлистов
    private func loadRecentSetlists(_ groupId: String) {
        db.collection("setlists")
            .whereField("groupId", isEqualTo: groupId)
            .limit(to: 5)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let setlists = docs.compactMap { try? $0.data(as: Setlist.self) }
                    
                    DispatchQueue.main.async {
                        self?.recentSetlists = setlists
                        self?.stats.setlistCount = setlists.count
                        
                        // Загружаем задачи
                        self?.loadPendingTasks(groupId)
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.loadPendingTasks(groupId)
                    }
                }
            }
    }
    
    // Загрузка незавершенных задач
    private func loadPendingTasks(_ groupId: String) {
        db.collection("tasks")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("completed", isEqualTo: false)
            .order(by: "dueDate")
            .limit(to: 5)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let tasks = docs.compactMap { try? $0.data(as: TaskModel.self) }
                    
                    DispatchQueue.main.async {
                        self?.pendingTasks = tasks
                        self?.stats.taskCount = tasks.count
                        
                        // Загружаем недавних участников
                        self?.loadRecentMembers(groupId)
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.loadRecentMembers(groupId)
                    }
                }
            }
    }
    
    // Загрузка недавно добавленных участников
    private func loadRecentMembers(_ groupId: String) {
        guard let group = self.group else {
            isLoading = false
            return
        }
        
        // Берем только последних 5 участников
        let memberIds = Array(group.members.prefix(5))
        
        UserService.shared.fetchUsers(ids: memberIds) { [weak self] users in
            DispatchQueue.main.async {
                self?.recentMembers = users
                self?.isLoading = false
            }
        }
    }
}