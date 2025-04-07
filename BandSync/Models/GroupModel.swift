import Foundation
import FirebaseFirestore

struct GroupModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var code: String
    var members: [String]
    var pendingMembers: [String]
    var createdAt: Date?
    var settings: GroupSettings?
    
    // Инициализатор по умолчанию
    init(id: String? = nil,
         name: String,
         code: String,
         members: [String],
         pendingMembers: [String],
         createdAt: Date? = nil,
         settings: GroupSettings? = nil) {
        self.id = id
        self.name = name
        self.code = code
        self.members = members
        self.pendingMembers = pendingMembers
        self.createdAt = createdAt
        self.settings = settings ?? GroupSettings()
    }
    
    // Настройки группы
    struct GroupSettings: Codable, Equatable {
        var allowMembersToInvite: Bool = true
        var allowMembersToCreateEvents: Bool = true
        var allowMembersToCreateSetlists: Bool = true
        var allowGuestAccess: Bool = false
        var enableNotifications: Bool = true
        var moduleSettings: ModuleSettings = ModuleSettings()
        
        // Настройки модулей группы
        struct ModuleSettings: Codable, Equatable {
            var enabledModules: [String] = [
                "calendar", "setlists", "tasks",
                "chats", "finances", "merchandise",
                "contacts", "admin"
            ]
            
            // Проверка, включен ли модуль
            func isModuleEnabled(_ moduleType: ModuleType) -> Bool {
                return enabledModules.contains(moduleType.rawValue)
            }
        }
    }
    
    // Реализация Equatable для сравнения объектов
    static func == (lhs: GroupModel, rhs: GroupModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.code == rhs.code &&
               lhs.members == rhs.members &&
               lhs.pendingMembers == rhs.pendingMembers &&
               lhs.createdAt == rhs.createdAt &&
               lhs.settings == rhs.settings
    }
    
    // Расширенная информация о состоянии группы
    var memberCount: Int {
        return members.count
    }
    
    var pendingCount: Int {
        return pendingMembers.count
    }
    
    var enabledModuleTypes: [ModuleType] {
        guard let moduleSettings = settings?.moduleSettings else {
            return ModuleType.allCases
        }
        
        return ModuleType.allCases.filter { moduleSettings.isModuleEnabled($0) }
    }
    
    var isModuleEnabled: [ModuleType: Bool] {
        guard let moduleSettings = settings?.moduleSettings else {
            return Dictionary(uniqueKeysWithValues: ModuleType.allCases.map { ($0, true) })
        }
        
        return Dictionary(uniqueKeysWithValues: ModuleType.allCases.map { ($0, moduleSettings.isModuleEnabled($0)) })
    }
}
