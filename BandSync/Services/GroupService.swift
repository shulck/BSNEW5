//
//  GroupService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 04.04.2025.
//

import Foundation
import FirebaseFirestore
import Combine

final class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var group: GroupModel?
    @Published var groupMembers: [UserModel] = []
    @Published var pendingMembers: [UserModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Настройка подписки на изменение пользователя
        AppState.shared.$user
            .compactMap { $0?.groupId }
            .removeDuplicates()
            .sink { [weak self] groupId in
                self?.fetchGroup(by: groupId)
            }
            .store(in: &cancellables)
    }
    
    // Получение информации о группе по ID
    func fetchGroup(by id: String) {
        isLoading = true
        errorMessage = nil
        
        db.collection("groups").document(id).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Ошибка загрузки группы: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            if let data = try? snapshot?.data(as: GroupModel.self) {
                DispatchQueue.main.async {
                    self.group = data
                    self.fetchGroupMembers(groupId: id)
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Ошибка преобразования данных группы"
                    self.isLoading = false
                }
            }
        }
    }

    // Получение информации о пользователях группы
    private func fetchGroupMembers(groupId: String) {
        guard let group = self.group else { return }
        
        // Очистка существующих данных
        self.groupMembers = []
        self.pendingMembers = []
        
        // Получение активных участников
        let memberBatch = group.members.chunked(into: 10)
        for memberChunk in memberBatch {
            fetchUserBatch(userIds: memberChunk, isActive: true)
        }
        
        // Получение ожидающих участников
        let pendingBatch = group.pendingMembers.chunked(into: 10)
        for pendingChunk in pendingBatch {
            fetchUserBatch(userIds: pendingChunk, isActive: false)
        }
    }
    
    // Получение данных пользователей пакетами
    private func fetchUserBatch(userIds: [String], isActive: Bool) {
        guard !userIds.isEmpty else { return }
        
        db.collection("users")
            .whereField(FieldPath.documentID(), in: userIds)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents, !documents.isEmpty else { return }
                
                let users = documents.compactMap { try? $0.data(as: UserModel.self) }
                DispatchQueue.main.async {
                    if isActive {
                        self.groupMembers.append(contentsOf: users)
                    } else {
                        self.pendingMembers.append(contentsOf: users)
                    }
                }
            }
    }
    
    // Одобрение пользователя (перемещение из ожидания в участники)
    func approveUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // Создание транзакции для безопасного перемещения пользователя
        db.runTransaction({ [weak self] (transaction, errorPointer) -> Any? in
            let groupRef = self?.db.collection("groups").document(groupId)
            
            guard let groupDoc = try? transaction.getDocument(groupRef!),
                  var group = try? groupDoc.data(as: GroupModel.self),
                  group.pendingMembers.contains(userId) else {
                return nil
            }
            
            // Удаление пользователя из списка ожидающих
            group.pendingMembers.removeAll { $0 == userId }
            
            // Добавление пользователя в список участников (если его там еще нет)
            if !group.members.contains(userId) {
                group.members.append(userId)
            }
            
            // Обновление группы
            if let groupRef = groupRef {
                try? transaction.setData(from: group, forDocument: groupRef)
            }
            
            return group
        }) { [weak self] (_, error) in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка одобрения пользователя: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Пользователь одобрен успешно"
                    
                    // Обновление локальных данных
                    if let pendingIndex = self?.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        if let user = self?.pendingMembers[pendingIndex] {
                            self?.groupMembers.append(user)
                            self?.pendingMembers.remove(at: pendingIndex)
                        }
                    }
                }
            }
        }
    }

    // Отклонение заявки пользователя
    func rejectUser(userId: String) {
        guard let groupId = group?.id else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // Создание пакетного обновления
        let batch = db.batch()
        
        // Удаление пользователя из списка ожидающих в группе
        let groupRef = db.collection("groups").document(groupId)
        batch.updateData([
            "pendingMembers": FieldValue.arrayRemove([userId])
        ], forDocument: groupRef)
        
        // Очистка groupId в профиле пользователя
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "groupId": NSNull()
        ], forDocument: userRef)
        
        // Выполнение пакетного обновления
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка отклонения заявки: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Заявка отклонена"
                    
                    // Обновление локальных данных
                    if let pendingIndex = self?.pendingMembers.firstIndex(where: { $0.id == userId }) {
                        self?.pendingMembers.remove(at: pendingIndex)
                    }
                }
            }
        }
    }

    // Удаление пользователя из группы
    func removeUser(userId: String, completion: ((Bool) -> Void)? = nil) {
        guard let groupId = group?.id else {
            completion?(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // Проверка, не удаляем ли мы последнего админа
        let isLastAdmin = groupMembers.filter { $0.role == .admin }.count <= 1 &&
                          groupMembers.first(where: { $0.id == userId })?.role == .admin
        
        if isLastAdmin {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Невозможно удалить единственного администратора группы"
                completion?(false)
            }
            return
        }
        
        // Создание пакетного обновления
        let batch = db.batch()
        
        // Удаление пользователя из списка участников группы
        let groupRef = db.collection("groups").document(groupId)
        batch.updateData([
            "members": FieldValue.arrayRemove([userId])
        ], forDocument: groupRef)
        
        // Очистка groupId в профиле пользователя
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "groupId": NSNull(),
            "role": UserModel.UserRole.member.rawValue // Сброс роли до участника
        ], forDocument: userRef)
        
        // Выполнение пакетного обновления
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка удаления пользователя: \(error.localizedDescription)"
                    completion?(false)
                } else {
                    self?.successMessage = "Пользователь удален из группы"
                    
                    // Обновление локальных данных
                    if let memberIndex = self?.groupMembers.firstIndex(where: { $0.id == userId }) {
                        self?.groupMembers.remove(at: memberIndex)
                    }
                    
                    completion?(true)
                }
            }
        }
    }

    // Обновление названия группы
    func updateGroupName(_ newName: String, completion: ((Bool) -> Void)? = nil) {
        guard let groupId = group?.id, !newName.isEmpty else {
            completion?(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        db.collection("groups").document(groupId).updateData([
            "name": newName
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка обновления названия: \(error.localizedDescription)"
                    completion?(false)
                } else {
                    self?.successMessage = "Название группы обновлено"
                    
                    // Обновление локальных данных
                    self?.group?.name = newName
                    completion?(true)
                }
            }
        }
    }

    // Генерация нового кода приглашения
    func regenerateCode() {
        guard let groupId = group?.id else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let newCode = UUID().uuidString.prefix(6).uppercased()

        db.collection("groups").document(groupId).updateData([
            "code": String(newCode)
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка обновления кода: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Новый код приглашения создан"
                    
                    // Обновление локальных данных
                    self?.group?.code = String(newCode)
                }
            }
        }
    }
    
    // Изменение роли пользователя
    func changeUserRole(userId: String, newRole: UserModel.UserRole) {
        guard userId != AppState.shared.user?.id || newRole == .admin else {
            // Нельзя понизить самого себя, если ты не остаешься админом
            errorMessage = "Невозможно изменить свою роль"
            return
        }
        
        // Проверка, не удаляем ли мы последнего админа
        let isLastAdmin = groupMembers.filter { $0.role == .admin }.count <= 1 &&
                          groupMembers.first(where: { $0.id == userId })?.role == .admin &&
                          newRole != .admin
        
        if isLastAdmin {
            errorMessage = "Необходимо иметь хотя бы одного администратора в группе"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        db.collection("users").document(userId).updateData([
            "role": newRole.rawValue
        ]) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка изменения роли: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Роль пользователя изменена"
                    
                    // Обновление локальных данных
                    if let memberIndex = self?.groupMembers.firstIndex(where: { $0.id == userId }) {
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
    
    // Создание новой группы
    func createGroup(name: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !name.isEmpty else {
            completion(.failure(NSError(domain: "EmptyGroupName", code: -1, userInfo: nil)))
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let groupCode = UUID().uuidString.prefix(6).uppercased()
        let newGroup = GroupModel(
            name: name,
            code: String(groupCode),
            members: [userId],
            pendingMembers: []
        )
        
        do {
            try db.collection("groups").addDocument(from: newGroup) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Ошибка создания группы: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                    return
                }
                
                // Получение ID созданной группы
                self.db.collection("groups")
                    .whereField("code", isEqualTo: groupCode)
                    .getDocuments { [weak self] snapshot, error in
                        guard let self = self else { return }
                        
                        self.isLoading = false
                        
                        if let error = error {
                            DispatchQueue.main.async {
                                self.errorMessage = "Ошибка получения ID группы: \(error.localizedDescription)"
                                completion(.failure(error))
                            }
                            return
                        }
                        
                        if let groupId = snapshot?.documents.first?.documentID {
                            // Пакетное обновление: присвоение groupId пользователю и установка роли админа
                            let batch = self.db.batch()
                            let userRef = self.db.collection("users").document(userId)
                            
                            batch.updateData([
                                "groupId": groupId,
                                "role": "Admin"
                            ], forDocument: userRef)
                            
                            batch.commit { error in
                                if let error = error {
                                    DispatchQueue.main.async {
                                        self.errorMessage = "Ошибка обновления пользователя: \(error.localizedDescription)"
                                        completion(.failure(error))
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        self.successMessage = "Группа успешно создана!"
                                        completion(.success(groupId))
                                    }
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.errorMessage = "Не удалось найти созданную группу"
                                completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                            }
                        }
                    }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Ошибка создания группы: \(error.localizedDescription)"
                completion(.failure(error))
            }
        }
    }
    
    // Присоединение к существующей группе по коду
    func joinGroup(code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = AuthService.shared.currentUserUID(), !code.isEmpty else {
            completion(.failure(NSError(domain: "EmptyGroupCode", code: -1, userInfo: nil)))
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        db.collection("groups")
            .whereField("code", isEqualTo: code)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Ошибка поиска группы: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Группа с этим кодом не найдена"
                        completion(.failure(NSError(domain: "GroupNotFound", code: -1, userInfo: nil)))
                    }
                    return
                }
                
                let groupId = document.documentID
                
                // Пакетное обновление: добавление пользователя в pendingMembers и обновление его профиля
                let batch = self.db.batch()
                
                // Обновление группы
                let groupRef = self.db.collection("groups").document(groupId)
                batch.updateData([
                    "pendingMembers": FieldValue.arrayUnion([userId])
                ], forDocument: groupRef)
                
                // Обновление пользователя
                let userRef = self.db.collection("users").document(userId)
                batch.updateData([
                    "groupId": groupId
                ], forDocument: userRef)
                
                batch.commit { error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let error = error {
                            self.errorMessage = "Ошибка присоединения к группе: \(error.localizedDescription)"
                            completion(.failure(error))
                        } else {
                            self.successMessage = "Заявка на вступление отправлена. Ожидайте подтверждения."
                            completion(.success(()))
                        }
                    }
                }
            }
    }
    
    // Проверка, является ли пользователь администратором
    func isUserAdmin(userId: String) -> Bool {
        return groupMembers.first(where: { $0.id == userId })?.role == .admin
    }
    
    // Проверка, является ли пользователь участником группы
    func isUserMember(userId: String) -> Bool {
        return group?.members.contains(userId) == true
    }
    
    // Метод для приглашения пользователя по электронной почте
    func inviteUserByEmail(email: String, to groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Найти пользователя по email
        UserService.shared.findUserByEmail(email) { [weak self] result in
            switch result {
            case .success(let user):
                if let user = user {
                    // Пользователь найден, добавляем его в список ожидающих подтверждения
                    let batch = self?.db.batch()
                    
                    // Обновление группы
                    let groupRef = self?.db.collection("groups").document(groupId)
                    batch?.updateData([
                        "pendingMembers": FieldValue.arrayUnion([user.id])
                    ], forDocument: groupRef!)
                    
                    // Обновление пользователя
                    let userRef = self?.db.collection("users").document(user.id)
                    batch?.updateData([
                        "groupId": groupId
                    ], forDocument: userRef!)
                    
                    batch?.commit { error in
                        if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.success(()))
                        }
                    }
                } else {
                    // Пользователь не найден
                    let error = NSError(domain: "UserNotFound", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пользователь с таким email не найден"])
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// Расширение для разбиения массива на части
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
