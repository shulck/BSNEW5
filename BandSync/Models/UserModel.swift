import Foundation

struct UserModel: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let phone: String
    let groupId: String?
    var role: UserRole

    enum UserRole: String, Codable, CaseIterable, Identifiable {
        case admin = "Admin"
        case manager = "Manager"
        case musician = "Musician"
        case member = "Member"
        
        var id: String { rawValue }
    }
    
    // Implementation of Equatable
    static func == (lhs: UserModel, rhs: UserModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.name == rhs.name &&
               lhs.phone == rhs.phone &&
               lhs.groupId == rhs.groupId &&
               lhs.role == rhs.role
    }
}
