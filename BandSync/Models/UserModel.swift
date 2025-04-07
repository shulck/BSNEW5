import Foundation
import FirebaseFirestore

struct UserModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var email: String
    var name: String
    var phone: String
    var groupId: String?
    var role: UserRole
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, phone, groupId, role
    }

    enum UserRole: String, Codable, CaseIterable, Identifiable {
        case admin = "Admin"
        case manager = "Manager"
        case musician = "Musician"
        case member = "Member"
        
        var id: String { rawValue }
    }
    
    // Дополнительный инициализатор для совместимости
    init(id: String = UUID().uuidString, email: String, name: String, phone: String, groupId: String?, role: UserRole) {
        self.id = id
        self.email = email
        self.name = name
        self.phone = phone
        self.groupId = groupId
        self.role = role
    }
    
    // Декодирование с обработкой возможных несоответствий
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        
        // Безопасное декодирование groupId, который может быть nil
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        
        // Безопасное декодирование role с fallback на member
        if let roleString = try? container.decode(String.self, forKey: .role),
           let decodedRole = UserRole(rawValue: roleString) {
            role = decodedRole
        } else {
            role = .member
        }
    }
    
    // Реализация Equatable
    static func == (lhs: UserModel, rhs: UserModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.name == rhs.name &&
               lhs.phone == rhs.phone &&
               lhs.groupId == rhs.groupId &&
               lhs.role == rhs.role
    }
}
