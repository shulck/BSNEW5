//
//  AppState.swift
//  BandSync
//
//  Created by Claude AI on 04.04.2025.
//

import Foundation
import FirebaseAuth
import Combine

final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isLoggedIn = false
    @Published var user: UserModel?
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refreshAuthState()
        
        // Подписка на события аутентификации Firebase
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.refreshAuthState()
        }
    }
    
    // Обновление состояния аутентификации
    func refreshAuthState() {
        isLoading = true
        
        if AuthService.shared.isUserLoggedIn(), let uid = AuthService.shared.currentUserUID() {
            // Получение пользователя из Firestore
            UserService.shared.fetchUser(uid: uid) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    switch result {
                    case .success(let user):
                        self?.user = user
                        self?.isLoggedIn = true
                    case .failure:
                        self?.user = nil
                        self?.isLoggedIn = false
                    }
                }
            }
        } else {
            isLoading = false
            user = nil
            isLoggedIn = false
        }
    }
    
    // Выход из системы
    func logout() {
        isLoading = true
        AuthService.shared.signOut { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.user = nil
                    self?.isLoggedIn = false
                case .failure:
                    // Логирование ошибки если нужно
                    break
                }
            }
        }
    }
    
    // Проверка, имеет ли пользователь права редактирования для модуля
    func hasEditPermission(for moduleId: ModuleType) -> Bool {
        guard let role = user?.role else {
            return false
        }
        
        // Только админы и менеджеры могут редактировать
        return role == .admin || role == .manager
    }
}

// Расширение AppState с методами для работы с группами
extension AppState {
    
    // Проверка, является ли пользователь администратором группы
    var isGroupAdmin: Bool {
        user?.role == .admin
    }
    
    // Проверка, имеет ли пользователь права менеджера группы
    var isGroupManager: Bool {
        user?.role == .admin || user?.role == .manager
    }
    
    // Проверка, имеет ли пользователь доступ к модулю
    func canAccessModule(_ moduleType: ModuleType) -> Bool {
        // Проверяем наличие доступа через PermissionService
        return PermissionService.shared.currentUserHasAccess(to: moduleType)
    }
    
    // Проверка, может ли пользователь создавать события
    func canCreateEvents() -> Bool {
        // Администраторы и менеджеры всегда могут
        if isGroupManager {
            return true
        }
        
        // Проверка настроек группы, разрешают ли они обычным участникам создавать события
        if let settings = GroupService.shared.group?.settings {
            return settings.allowMembersToCreateEvents
        }
        
        // По умолчанию запрещаем
        return false
    }
    
    // Проверка, может ли пользователь создавать сетлисты
    func canCreateSetlists() -> Bool {
        // Администраторы и менеджеры всегда могут
        if isGroupManager {
            return true
        }
        
        // Проверка настроек группы, разрешают ли они обычным участникам создавать сетлисты
        if let settings = GroupService.shared.group?.settings {
            return settings.allowMembersToCreateSetlists
        }
        
        // По умолчанию запрещаем
        return false
    }
    
    // Проверка, может ли пользователь приглашать других участников
    func canInviteMembers() -> Bool {
        // Администраторы и менеджеры всегда могут
        if isGroupManager {
            return true
        }
        
        // Проверка настроек группы, разрешают ли они обычным участникам приглашать
        if let settings = GroupService.shared.group?.settings {
            return settings.allowMembersToInvite
        }
        
        // По умолчанию запрещаем
        return false
    }
    
    // Проверка, находится ли пользователь в группе
    var isInGroup: Bool {
        user?.groupId != nil
    }
    
    // Проверка, ожидает ли пользователь подтверждения присоединения к группе
    var isPendingGroupApproval: Bool {
        guard let groupId = user?.groupId,
              let userId = user?.id else {
            return false
        }
        
        // Проверяем, находится ли ID пользователя в списке pendingMembers группы
        if let pendingMembers = GroupService.shared.group?.pendingMembers {
            return pendingMembers.contains(userId)
        }
        
        return false
    }
    
    // Проверка, является ли пользователь полноценным участником группы
    var isActiveGroupMember: Bool {
        guard let groupId = user?.groupId,
              let userId = user?.id else {
            return false
        }
        
        // Проверяем, находится ли ID пользователя в списке members группы
        if let members = GroupService.shared.group?.members {
            return members.contains(userId)
        }
        
        return false
    }
    
    // Покинуть текущую группу
    func leaveCurrentGroup(completion: @escaping (Bool) -> Void) {
        guard let userId = user?.id,
              let groupId = user?.groupId else {
            completion(false)
            return
        }
        
        isLoading = true
        
        // Используем GroupService для удаления пользователя из группы
        GroupService.shared.removeUser(userId: userId) { [weak self] success in
            if success {
                // Если успешно удалили из группы, обновляем данные пользователя
                UserService.shared.clearUserGroup { result in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        switch result {
                        case .success:
                            // Обновляем состояние приложения
                            self?.refreshAuthState()
                            completion(true)
                        case .failure:
                            completion(false)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    completion(false)
                }
            }
        }
    }
}
