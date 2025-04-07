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
    private var groupListener: ListenerRegistration?
    
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
    
    deinit {
        groupListener?.remove()
    }
    
    // Получение информации о группе по ID с улучшенной обработкой ошибок
    func fetchGroup(by id: String) {
        isLoading = true
        errorMessage = nil
        
        // Удаляем предыдущий слушатель, если есть
        groupListener?.remove()
        
        // Создаем нового слушателя для отслеживания изменений в группе
        groupListener = db.collection("groups").document(id).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Ошибка загрузки группы: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            if let document = snapshot, document.exists {
                do {
                    let group = try document.data(as: GroupModel.self)
                    DispatchQueue.main.async {
                        self.group = group
                        self.isLoading = false
                        self.fetchGroupMembers()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Ошибка преобразования данных группы: \(error.localizedDescription)"
                        self.isLoading = false
                        
                        // Попытка восстановить данные вручную
                        let data = document.data()
                        if data != nil {
                            self.createGroupFromData(id: id, data: data!)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Группа не найдена"
                    self.isLoading = false
                }
            }
        }
    }
    
    // Ручное создание модели группы из данных
    private func createGroupFromData(id: String, data: [String: Any]) {
        guard let name = data["name"] as? String,
              let code = data["code"] as? String else {
            self.errorMessage = "Отсутствуют обязательные поля группы"
            return
        }
        
        let members = data["members"] as? [String] ?? []
        let pendingMembers = data["pendingMembers"] as? [String] ?? []
        let createdAtTimestamp = data["createdAt"] as? Timestamp
        let createdAt = createdAtTimestamp?.dateValue()
        
        let settingsData = data["settings"] as? [String: Any]
        let settings = createSettingsFromData(settingsData)
        
        let group = GroupModel(
            id: id,
            name: name,
            code: code,
            members: members,
            pendingMembers: pendingMembers,
            createdAt: createdAt,
            settings: settings
        )
        
        self.group = group
        self.fetchGroupMembers()
    }
    
    // Ручное создание настроек из данных
    private func createSettingsFromData(_ data: [String: Any]?) -> GroupModel.GroupSettings {
        var allowMembersToInvite = true
        var allowMembersToCreateEvents = true
        var allowMembersToCreateSetlists = true
        var allowGuestAccess = false
        var enableNotifications = true
        var enabledModules = ModuleType.allCases.map { $0.rawValue }
        
        if let data = data {
            if let value = data["allowMembersToInvite"] as? Bool {
                allowMembersToInvite = value
            }
            
            if let value = data["allowMembersToCreateEvents"] as? Bool {
                allowMembersToCreateEvents = value
            }
            
            if let value = data["allowMembersToCreateSetlists"] as? Bool {
                allowMembersToCreateSetlists = value
            }
            
            if let value = data["allowGuestAccess"] as? Bool {
                allowGuestAccess = value
            }
            
            if let value = data["enableNotifications"] as? Bool {
                enableNotifications = value
            }
            
            if let moduleSettingsData = data["moduleSettings"] as? [String: Any],
               let modules = moduleSettingsData["enabledModules"] as? [String] {
                enabledModules = modules
            }
        }

        // Создаем настройки с полученными значениями
        let settings = GroupModel.GroupSettings(
            allowMembersToInvite: allowMembersToInvite,
            allowMembersToCreateEvents: allowMembersToCreateEvents,
            allowMembersToCreateSetlists: allowMembersToCreateSetlists,
            allowGuestAccess: allowGuestAccess,
            enableNotifications: enableNotifications,
            moduleSettings: GroupModel.GroupSettings.ModuleSettings(enabledModules: enabledModules)
        )
        
        return settings
    }

    // Получение информации о пользователях группы с улучшенной обработкой ошибок
    func fetchGroupMembers() {
        guard let group = self.group else { return }
        
        // Очистка существующих данных
        self.groupMembers = []
        self.pendingMembers = []
        
        // Обработка пустых списков
        if group.members.isEmpty && group.pendingMembers.isEmpty {
            return
        }
        
        isLoading = true
        
        // Получение активных участников
        if !group.members.isEmpty {
            fetchUserBatch(userIds: group.members, isActive: true)
        }
        
        // Получение ожидающих участников
        if !group.pendingMembers.isEmpty {
            fetchUserBatch(userIds: group.pendingMembers, isActive: false)
        }
    }
    
    // Получение данных пользователей с улучшенной обработкой ошибок
    private func fetchUserBatch(userIds: [String], isActive: Bool) {
        let batchSize = 10
        var remainingIds = userIds
        
        // Функция для обработки следующего пакета
        func processNextBatch() {
            guard !remainingIds.isEmpty else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            let currentBatch = Array(remainingIds.prefix(batchSize))
            remainingIds = Array(remainingIds.dropFirst(min(batchSize, remainingIds.count)))
            
            db.collection("users")
                .whereField(FieldPath.documentID(), in: currentBatch)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Ошибка загрузки пользователей: \(error.localizedDescription)"
                            
                            // Продолжаем с следующим пакетом даже при ошибке
                            processNextBatch()
                        }
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        DispatchQueue.main.async {
                            processNextBatch()
                        }
                        return
                    }
                    
                    // Обработка полученных документов
                    let users = documents.compactMap { doc -> UserModel? in
                        do {
                            // Пытаемся декодировать как модель
                            return try doc.data(as: UserModel.self)
                        } catch {
                            print("GroupService: ошибка декодирования пользователя: \(error.localizedDescription)")
                            
                            // Если не получилось, собираем вручную
                            let data = doc.data()
                            let id = doc.documentID
                            if let email = data["email"] as? String {
                                let name = data["name"] as? String ?? "Unknown User"
                                let phone = data["phone"] as? String ?? ""
                                let groupId = data["groupId"] as? String
                                let roleString = data["role"] as? String ?? "Member"
                                let role = UserModel.UserRole(rawValue: roleString) ?? .member
                                
                                return UserModel(
                                    id: id,
                                    email: email,
                                    name: name,
                                    phone: phone,
                                    groupId: groupId,
                                    role: role
                                )
                            }
                            return nil
                        }
                    }
                    
                    DispatchQueue.main.async {
                        // Добавляем пользователей в соответствующие массивы
                        if isActive {
                            self.groupMembers.append(contentsOf: users)
                        } else {
                            self.pendingMembers.append(contentsOf: users)
                        }
                        
                        // Обрабатываем следующий пакет
                        processNextBatch()
                    }
                }
        }
        
        // Запускаем первый пакет
        processNextBatch()
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
            
            guard let document = try? transaction.getDocument(groupRef!),
                  let data = document.data() else {
                return nil
            }
            
            // Получаем массивы участников
            var members = data["members"] as? [String] ?? []
            var pendingMembers = data["pendingMembers"] as? [String] ?? []
            
            // Проверяем, что пользователь в списке ожидающих
            guard pendingMembers.contains(userId) else {
                return nil
            }
            
            // Удаляем пользователя из списка ожидающих
            pendingMembers.removeAll { $0 == userId }
            
            // Добавляем пользователя в список участников (если его там еще нет)
            if !members.contains(userId) {
                members.append(userId)
            }
            
            // Обновляем группу
            if let groupRef = groupRef {
                transaction.updateData([
                    "members": members,
                    "pendingMembers": pendingMembers
                ], forDocument: groupRef)
            }
            
            return [members, pendingMembers]
        }) { [weak self] (result, error) in
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
                            
                            // Обновляем локальную модель группы
                            if var updatedGroup = self?.group {
                                updatedGroup.members.append(userId)
                                updatedGroup.pendingMembers.removeAll { $0 == userId }
                                self?.group = updatedGroup
                            }
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
            "groupId": FieldValue.delete()
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
                    
                    // Обновляем локальную модель группы
                    if var updatedGroup = self?.group {
                        updatedGroup.pendingMembers.removeAll { $0 == userId }
                        self?.group = updatedGroup
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
            "groupId": FieldValue.delete(),
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
                    
                    // Обновляем локальную модель группы
                    if var updatedGroup = self?.group {
                        updatedGroup.members.removeAll { $0 == userId }
                        self?.group = updatedGroup
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
        guard let currentUserId = AppState.shared.user?.id, userId != currentUserId || newRole == .admin else {
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
        
        // Создаем настройки по умолчанию
        let settings = GroupModel.GroupSettings()
        
        let newGroup = GroupModel(
            name: name,
            code: String(groupCode),
            members: [userId],
            pendingMembers: [],
            createdAt: Date(),
            settings: settings
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
                        "pendingMembers": FieldValue.arrayUnion([user.id ?? ""])
                    ], forDocument: groupRef!)
                    
                    // Обновление пользователя
                    let userRef = self?.db.collection("users").document(user.id ?? "")
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
