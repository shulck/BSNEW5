//
//  AdminPanelView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 04.04.2025.
//

import SwiftUI

struct AdminPanelView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Управление группой")) {
                    // Добавляем ссылку на полный обзор группы
                    NavigationLink(destination: GroupDetailView()) {
                        Label("Информация о группе", systemImage: "music.mic")
                    }
                    
                    // Группа и статистика
                    NavigationLink(destination: GroupActivityView()) {
                        Label("Активность группы", systemImage: "chart.bar")
                    }
                    
                    // Настройки группы
                    NavigationLink(destination: GroupSettingsView()) {
                        Label("Настройки группы", systemImage: "gearshape")
                    }
                    
                    // Управление участниками
                    NavigationLink(destination: UsersListView()) {
                        Label("Участники группы", systemImage: "person.3")
                    }
                    
                    // Управление правами доступа
                    NavigationLink(destination: PermissionsView()) {
                        Label("Права доступа", systemImage: "lock.shield")
                    }
                    
                    // Управление модулями
                    NavigationLink(destination: ModuleManagementView()) {
                        Label("Модули приложения", systemImage: "square.grid.2x2")
                    }
                }
                
                Section(header: Text("Статистика")) {
                    // Число участников
                    Label("Число участников: \(groupService.groupMembers.count)", systemImage: "person.2")
                    
                    if let group = groupService.group {
                        Label("Название группы: \(group.name)", systemImage: "music.mic")
                        
                        // Код приглашения с возможностью копирования
                        HStack {
                            Label("Код приглашения: \(group.code)", systemImage: "qrcode")
                            Spacer()
                            Button {
                                UIPasteboard.general.string = group.code
                                alertMessage = "Код скопирован в буфер обмена"
                                showAlert = true
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section(header: Text("Дополнительно")) {
                    Button(action: {
                        // Функция для тестирования уведомлений
                        alertMessage = "Уведомления будут реализованы в следующем обновлении"
                        showAlert = true
                    }) {
                        Label("Тестировать уведомления", systemImage: "bell")
                    }
                    
                    Button(action: {
                        // Функция экспорта данных группы
                        exportGroupData()
                    }) {
                        Label("Экспорт данных группы", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Панель администратора")
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    groupService.fetchGroup(by: groupId)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Информация"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .refreshable {
                if let groupId = AppState.shared.user?.groupId {
                    groupService.fetchGroup(by: groupId)
                }
            }
        }
    }
    
    // Функция экспорта данных группы
    private func exportGroupData() {
        guard let groupId = AppState.shared.user?.groupId else {
            alertMessage = "Не удалось определить группу"
            showAlert = true
            return
        }
        
        // Здесь можно реализовать экспорт данных группы в CSV или другой формат
        // В данном примере просто показываем сообщение
        alertMessage = "Экспорт данных группы будет реализован в следующем обновлении"
        showAlert = true
    }
}
