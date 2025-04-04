//
//  GroupService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 04.04.2025.
//

import Foundation
import FirebaseFirestore

final class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var group: GroupModel?
    @Published var groupMembers: [UserModel] = []
    @Published var pendingMembers: [UserModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    deinit {
        // Отписываемся от всех слушателей при уничтожении объекта
        for listener in listeners {
            listener.remove()
        }
    }
    
    // Получить информацию о группе по ID
    func fetchGroup(by id: String) {
        isLoading = true
        
        // Отписываемся от предыдущих слушателей, если они были
        for listener in listeners {
            listener.remove()
        }
        listeners.removeAll()
        
        // Создаем нового слушателя для группы
        let groupListener = db.collection("groups").document(id).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Ошибка загрузки группы: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            if let document = snapshot, document.exists {
                do {
                    // Используем декодирование Firestore для конвертации данных
                    if var group = try document.data(as: GroupModel.self) {
                        // Добавим информацию о дате создания, если она отсутствует
                        if group.createdAt == nil {
                            if let creationTime = document.createTime?.dateValue() {
                                group.createdAt = creationTime
                            } else {
                                group.createdAt = Date()
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.group = group
                            self.fetchGroupMembers(groupId: id)
                            self.isLoading = false
                        }
                    } else {
                        self.errorMessage = "Ошибка декодирования данных группы"
                        self.isLoading = false
                    }
                } catch {
                    self.errorMessage = "Ошибка конвертации данных группы: \(error.localizedDescription)"
                    self.isLoading = false
                }
            } else {
                self.errorMessage = "Группа не найдена"
                self.isLoading = false
            }
        }
        
        // Сохраняем слушатель
        listeners.append(groupListener)
    }

    // Получить информацию о пользователях группы
    private func fetchGroupMembers(groupId: String) {
        guard let group = self.group else { return }
        
        // Очищаем текущие данные
        self.groupMembers = []
        self.pendingMembers = []
        
        // Получаем активных участников
        for memberId in group.members {
            db.collection("users").document(memberId).getDocument { [weak self] snapshot, error in
                if let userData = try? snapshot?.data(as: UserModel.self) {
                    DispatchQueue.main.async {
                        self?.groupMembers.append(userData)
                    }
                }
            }
        }
        
        // Получаем ожидающих участников
        for pendingId in group.pendingMembers {
            db.collection("users").document(pendingId).getDocument { [weak self] snapshot, error in
                if let userData = try? snapshot?.data(as: UserModel.self) {
                    DispatchQueue.main.async {
                        self?.pendingMembers.append(userData)
                    }
                }
            }
        }
    }

    // Обновить название группы
    func updateGroupName(_ newName: String, completion: ((Bool) -> Void)? = nil) {
        guard let groupId = group?.id else {
            completion?(false)
            return
        }
        
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "name": newName
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка обновления названия: \(error.localizedDescription)"
                    completion?(false)
                } else {
                    // Обновляем локальные данные
                    self?.group?.name = newName
                    completion?(true)
                }
            }
        }
    }

    // Сгенерировать новый код приглашения
    func regenerateCode() {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        let newCode = UUID().uuidString.prefix(6).uppercased()

        db.collection("groups").document(groupId).updateData([
            "code": String(newCode)
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка обновления кода: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    self?.group?.code = String(newCode)
                }
            }
        }
    }
    
    // Изменить роль пользователя
    func changeUserRole(userId: String, newRole: UserModel.UserRole) {
        isLoading = true
        
        // Проверка для случая, если пытаются снять роль администратора с единственного админа
        if newRole != .admin {
            let isAdmin = groupMembers.first(where: { $0.id == userId })?.role == .admin
            let otherAdmins = groupMembers.filter { $0.role == .admin && $0.id != userId }
            
            if isAdmin && otherAdmins.isEmpty {
                isLoading = false
                errorMessage = "Невозможно удалить права единственного администратора"
                return
            }
        }
        
        db.collection("users").document(userId).updateData([
            "role": newRole.rawValue
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка изменения роли: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    if let memberIndex = self?.groupMembers.firstIndex(where: { $0.id == userId }) {
                        // Для простоты создаем копию обновленного пользователя
                        var updatedUser = self?.groupMembers[memberIndex]
                        updatedUser?.role = newRole
                        
                        if let user = updatedUser {
                            self?.groupMembers[memberIndex] = user
                        }
                    }
                }
            }
        }
    }
    
    // Пригласить пользователя по email
    func inviteUserByEmail(email: String, to groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Проверяем, существует ли пользователь с таким email
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    // Пользователь найден
                    guard let userId = documents.first?.documentID else {
                        completion(.failure(NSError(domain: "GroupService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить ID пользователя"])))
                        return
                    }
                    
                    // Проверяем, не состоит ли пользователь уже в группе
                    if let userData = try? documents.first?.data(as: UserModel.self),
                       userData.groupId != nil && userData.groupId != groupId {
                        completion(.failure(NSError(domain: "GroupService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Пользователь уже состоит в другой группе"])))
                        return
                    }
                    
                    // Проверяем, не является ли пользователь уже членом или ожидающим подтверждения в этой группе
                    if let group = self.group,
                       group.members.contains(userId) || group.pendingMembers.contains(userId) {
                        completion(.failure(NSError(domain: "GroupService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Пользователь уже в группе или ожидает подтверждения"])))
                        return
                    }
                    
                    // Добавляем пользователя в список ожидающих подтверждения
                    self.db.collection("groups").document(groupId).updateData([
                        "pendingMembers": FieldValue.arrayUnion([userId])
                    ]) { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            // Обновляем groupId пользователя
                            self.db.collection("users").document(userId).updateData([
                                "groupId": groupId
                            ]) { error in
                                if let error = error {
                                    completion(.failure(error))
                                } else {
                                    // Отправка уведомления пользователю (можно реализовать позже)
                                    completion(.success(()))
                                }
                            }
                        }
                    }
                } else {
                    // Пользователь не найден
                    completion(.failure(NSError(domain: "GroupService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Пользователь с таким email не найден"])))
                }
            }
    }
    
    // Создание группы (перенесено из GroupViewModel для консистентности)
    func createGroup(name: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !name.isEmpty else {
            completion(.failure(NSError(domain: "GroupService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Необходимо указать название группы"])))
            return
        }
        
        isLoading = true
        
        let groupCode = UUID().uuidString.prefix(6).uppercased()
        let newGroup = GroupModel(
            name: name,
            code: String(groupCode),
            members: [userId],
            pendingMembers: [],
            createdAt: Date()
        )
        
        do {
            try db.collection("groups").addDocument(from: newGroup) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Ошибка создания группы: \(error.localizedDescription)"
                    self.isLoading = false
                    completion(.failure(error))
                    return
                }
                
                // Получить ID созданной группы
                self.db.collection("groups")
                    .whereField("code", isEqualTo: groupCode)
                    .getDocuments { snapshot, error in
                        self.isLoading = false
                        
                        if let error = error {
                            self.errorMessage = "Ошибка получения ID группы: \(error.localizedDescription)"
                            completion(.failure(error))
                            return
                        }
                        
                        if let groupId = snapshot?.documents.first?.documentID {
                            // Обновляем пользователя с ID группы
                            UserService.shared.updateUserGroup(groupId: groupId) { result in
                                switch result {
                                case .success:
                                    // Также обновляем роль пользователя на Admin
                                    self.db.collection("users").document(userId).updateData([
                                        "role": "Admin"
                                    ]) { error in
                                        if let error = error {
                                            self.errorMessage = "Ошибка назначения администратора: \(error.localizedDescription)"
                                            completion(.failure(error))
                                        } else {
                                            completion(.success(groupId))
                                        }
                                    }
                                case .failure(let error):
                                    self.errorMessage = "Ошибка обновления пользователя: \(error.localizedDescription)"
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            self.errorMessage = "Не удалось найти созданную группу"
                            completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                        }
                    }
            }
        } catch {
            isLoading = false
            errorMessage = "Ошибка создания группы: \(error.localizedDescription)"
            completion(.failure(error))
        }
    }
    
    // Присоединение к группе по коду (перенесено из GroupViewModel для консистентности)
    func joinGroup(code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !code.isEmpty else {
            completion(.failure(NSError(domain: "GroupService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Необходимо указать код группы"])))
            return
        }
        
        isLoading = true
        
        db.collection("groups")
            .whereField("code", isEqualTo: code)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Ошибка поиска группы: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    self.errorMessage = "Группа с таким кодом не найдена"
                    completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                    return
                }
                
                let groupId = document.documentID
                
                // Добавить пользователя в pendingMembers
                self.db.collection("groups").document(groupId).updateData([
                    "pendingMembers": FieldValue.arrayUnion([userId])
                ]) { error in
                    if let error = error {
                        self.errorMessage = "Ошибка присоединения к группе: \(error.localizedDescription)"
                        completion(.failure(error))
                    } else {
                        // Обновить groupId пользователя
                        UserService.shared.updateUserGroup(groupId: groupId) { result in
                            switch result {
                            case .success:
                                completion(.success(()))
                            case .failure(let error):
                                self.errorMessage = "Ошибка обновления пользователя: \(error.localizedDescription)"
                                completion(.failure(error))
                            }
                        }
                    }
                }
            }
    }
}
    
    // Подтвердить пользователя (перевести из ожидающих в участники)
    func approveUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId]),
            "members": FieldValue.arrayUnion([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка удаления пользователя: \(error.localizedDescription)"
                    completion?(false)
                } else {
                    // Обновляем локальные данные
                    if let memberIndex = self?.groupMembers.firstIndex(where: { $0.id == userId }) {
                        self?.groupMembers.remove(at: memberIndex)
                    }
                    
                    // Очищаем groupId в профиле пользователя
                    self?.db.collection("users").document(userId).updateData([
                        "groupId": NSNull()
                    ])
                    
                    completion?(true)
                } = error {
                    self?.errorMessage = "Ошибка подтверждения пользователя: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    if let pendingIndex = self?.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        if let user = self?.pendingMembers[pendingIndex] {
                            self?.groupMembers.append(user)
                            self?.pendingMembers.remove(at: pendingIndex)
                        }
                    }
                    
                    // Обновляем роль пользователя, если она не была установлена
                    self?.db.collection("users").document(userId).getDocument { snapshot, _ in
                        if let userData = snapshot?.data(),
                           let role = userData["role"] as? String,
                           role.isEmpty || role == "Member" {
                            self?.db.collection("users").document(userId).updateData([
                                "role": "Member"
                            ])
                        }
                    }
                }
            }
        }
    }

    // Отклонить заявку пользователя
    func rejectUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        
        db.collection("groups").document(groupId).updateData([
            "pendingMembers": FieldValue.arrayRemove([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка отклонения пользователя: \(error.localizedDescription)"
                } else {
                    // Обновляем локальные данные
                    if let pendingIndex = self?.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        self?.pendingMembers.remove(at: pendingIndex)
                    }
                    
                    // Очищаем groupId в профиле пользователя
                    self?.db.collection("users").document(userId).updateData([
                        "groupId": NSNull()
                    ])
                }
            }
        }
    }

    // Удалить пользователя из группы
    func removeUser(userId: String, completion: ((Bool) -> Void)? = nil) {
        guard let groupId = group?.id else {
            completion?(false)
            return
        }
        
        isLoading = true
        
        // Проверяем, является ли пользователь администратором
        let isAdmin = groupMembers.first(where: { $0.id == userId })?.role == .admin
        let otherAdmins = groupMembers.filter { $0.role == .admin && $0.id != userId }
        
        // Если пользователь админ и нет других админов, отменяем операцию
        if isAdmin && otherAdmins.isEmpty {
            isLoading = false
            errorMessage = "Невозможно удалить единственного администратора группы"
            completion?(false)
            return
        }
        
        db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayRemove([userId])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error
