import Foundation
import FirebaseFirestore
import FirebaseAuth

final class UserService: ObservableObject {
    static let shared = UserService()

    @Published var currentUser: UserModel?

    private let db = Firestore.firestore()

    private init() {}

    // Проверка существования пользователя и создание, если не существует
    func ensureUserExists(uid: String, email: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("UserService: ошибка проверки пользователя: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let document = snapshot, document.exists {
                do {
                    // Попытка получить существующего пользователя
                    let user = try document.data(as: UserModel.self)
                    self?.currentUser = user
                    completion(.success(user))
                } catch {
                    print("UserService: ошибка декодирования пользователя: \(error.localizedDescription)")

                    // Если документ существует, но декодирование не удалось,
                    // создаем новый документ, полностью заменяя существующий
                    self?.createUserProfile(uid: uid, email: email, completion: completion)
                }
            } else {
                // Пользователя нет, создаем
                self?.createUserProfile(uid: uid, email: email, completion: completion)
            }
        }
    }

    // Создание нового профиля пользователя
    private func createUserProfile(uid: String, email: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        // Создаем базовый профиль
        let newUser = UserModel(
            id: uid,
            email: email,
            name: email.components(separatedBy: "@").first ?? "User",
            phone: "",
            groupId: nil,
            role: .member
        )

        do {
            try db.collection("users").document(uid).setData(from: newUser) { error in
                if let error = error {
                    print("UserService: ошибка создания профиля: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                self.currentUser = newUser
                completion(.success(newUser))
            }
        } catch {
            print("UserService: ошибка сериализации профиля: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    // Получение пользователя по ID с исправленной логикой
    func fetchUser(uid: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("UserService: ошибка получения пользователя: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let document = snapshot, document.exists {
                do {
                    let user = try document.data(as: UserModel.self)
                    self?.currentUser = user
                    completion(.success(user))
                } catch {
                    print("UserService: ошибка декодирования пользователя: \(error.localizedDescription)")

                    // Попытка получить данные вручную, если декодирование не удалось
                    let data = document.data()
                    if let email = data?["email"] as? String {
                        self?.ensureUserExists(uid: uid, email: email, completion: completion)
                    } else {
                        completion(.failure(error))
                    }
                }
            } else {
                if let email = Auth.auth().currentUser?.email {
                    self?.ensureUserExists(uid: uid, email: email, completion: completion)
                } else {
                    let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден"])
                    completion(.failure(error))
                }
            }
        }
    }

    func updateUserGroup(groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не найден текущий пользователь"])
            completion(.failure(error))
            return
        }

        db.collection("users").document(uid).updateData([
            "groupId": groupId
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Обновление локальных данных
                if let user = self.currentUser {
                    // Создаем новый экземпляр с обновленным groupId
                    let updatedUser = UserModel(
                        id: user.id ?? "",
                        email: user.email,
                        name: user.name,
                        phone: user.phone,
                        groupId: groupId,
                        role: user.role
                    )
                    self.currentUser = updatedUser
                }
                completion(.success(()))
            }
        }
    }

    func clearUserGroup(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден"])
            completion(.failure(error))
            return
        }

        db.collection("users").document(uid).updateData([
            "groupId": NSNull()
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Обновляем локальные данные
                if let user = self.currentUser {
                    // Создаем новый экземпляр с очищенным groupId
                    let updatedUser = UserModel(
                        id: user.id ?? "",
                        email: user.email,
                        name: user.name,
                        phone: user.phone,
                        groupId: nil,
                        role: user.role
                    )
                    self.currentUser = updatedUser
                }

                completion(.success(()))
            }
        }
    }

    // Дополнительные методы

    func fetchUsers(ids: [String], completion: @escaping ([UserModel]) -> Void) {
        guard !ids.isEmpty else {
            completion([])
            return
        }

        // Ограничение Firestore: можно запрашивать не более 10 документов за раз
        let batchSize = 10
        var result: [UserModel] = []
        let dispatchGroup = DispatchGroup()

        // Разбиваем массив на пакеты по 10 элементов
        for i in stride(from: 0, to: ids.count, by: batchSize) {
            let end = min(i + batchSize, ids.count)
            let batch = Array(ids[i..<end])

            dispatchGroup.enter()

            db.collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { snapshot, error in
                    defer { dispatchGroup.leave() }

                    if let error = error {
                        print("UserService: ошибка получения пользователей: \(error.localizedDescription)")
                        return
                    }

                    if let documents = snapshot?.documents {
                        let users = documents.compactMap { doc -> UserModel? in
                            do {
                                return try doc.data(as: UserModel.self)
                            } catch {
                                print("UserService: ошибка декодирования пользователя: \(error.localizedDescription)")

                                // Ручная сборка пользователя если декодирование не удалось
                                let data = doc.data()
                                if let email = data["email"] as? String,
                                   let name = data["name"] as? String {
                                    let id = doc.documentID
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
                        result.append(contentsOf: users)
                    }
                }
        }

        dispatchGroup.notify(queue: .main) {
            completion(result)
        }
    }

    func findUserByEmail(_ email: String, completion: @escaping (Result<UserModel?, Error>) -> Void) {
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("UserService: ошибка поиска пользователя: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                if let document = snapshot?.documents.first {
                    do {
                        let user = try document.data(as: UserModel.self)
                        completion(.success(user))
                    } catch {
                        print("UserService: ошибка конвертации данных пользователя: \(error.localizedDescription)")

                        // Ручная сборка пользователя если декодирование не удалось
                        let data = document.data()
                        if let email = data["email"] as? String,
                           let name = data["name"] as? String {
                            let id = document.documentID
                            let phone = data["phone"] as? String ?? ""
                            let groupId = data["groupId"] as? String
                            let roleString = data["role"] as? String ?? "Member"
                            let role = UserModel.UserRole(rawValue: roleString) ?? .member

                            let user = UserModel(
                                id: id,
                                email: email,
                                name: name,
                                phone: phone,
                                groupId: groupId,
                                role: role
                            )
                            completion(.success(user))
                        } else {
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.success(nil))
                }
            }
    }
}
