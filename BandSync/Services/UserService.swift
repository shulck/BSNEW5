//
//  UserService.swift
//  BandSync
//
//  Created by Claude AI on 04.04.2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class UserService: ObservableObject {
    static let shared = UserService()
    
    @Published var currentUser: UserModel?
    
    let db = Firestore.firestore()
    
    private init() {}
    
    // Получение пользователя по ID
    func fetchUser(uid: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("UserService: ошибка получения пользователя: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let document = snapshot, document.exists {
                do {
                    let user = try document.data(as: UserModel.self)
                    self.currentUser = user
                    completion(.success(user))
                } catch {
                    print("UserService: ошибка декодирования пользователя: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else {
                let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден"])
                completion(.failure(error))
            }
        }
    }
    
    // Обновление ID группы пользователя
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
                        id: user.id,
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
    
    // Очистить groupId у пользователя при выходе из группы
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
                        id: user.id,
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
    
    // Получить список пользователей по массиву идентификаторов
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
                        let users = documents.compactMap { try? $0.data(as: UserModel.self) }
                        result.append(contentsOf: users)
                    }
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(result)
        }
    }
    
    // Проверить, является ли пользователь членом группы
    func isUserInGroup(userId: String, groupId: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("UserService: ошибка проверки группы пользователя: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let data = snapshot?.data(),
               let userGroupId = data["groupId"] as? String {
                completion(userGroupId == groupId)
            } else {
                completion(false)
            }
        }
    }
    
    // Получить всех пользователей группы (и активных, и ожидающих)
    func fetchAllGroupUsers(groupId: String, completion: @escaping (Result<[UserModel], Error>) -> Void) {
        db.collection("users")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("UserService: ошибка получения пользователей группы: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                if let documents = snapshot?.documents {
                    let users = documents.compactMap { try? $0.data(as: UserModel.self) }
                    completion(.success(users))
                } else {
                    completion(.success([]))
                }
            }
    }
    
    // Обновить роль пользователя
    func updateUserRole(userId: String, role: UserModel.UserRole, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(userId).updateData([
            "role": role.rawValue
        ]) { error in
            if let error = error {
                print("UserService: ошибка обновления роли: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("UserService: роль успешно обновлена")
                
                // Если обновляем текущего пользователя, то обновляем и локальные данные
                if userId == self.currentUser?.id, let user = self.currentUser {
                    // Создаем новый экземпляр с обновленной ролью
                    let updatedUser = UserModel(
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        phone: user.phone,
                        groupId: user.groupId,
                        role: role
                    )
                    self.currentUser = updatedUser
                }
                
                completion(.success(()))
            }
        }
    }
    
    // Найти пользователя по email
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
                        completion(.failure(error))
                    }
                } else {
                    completion(.success(nil))
                }
            }
    }
}
