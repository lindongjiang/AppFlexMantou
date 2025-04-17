import Foundation
import Security

class KeychainUUID {
    
    private static let uuidKey = "com.appflex.device.uuid"
    
    static func getUUID() -> String {
        if let uuid = getUUIDFromKeychain() {
            return uuid
        }
        
        let newUUID = UUID().uuidString
        saveUUIDToKeychain(newUUID)
        return newUUID
    }
    
    private static func getUUIDFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: uuidKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data, let uuid = String(data: data, encoding: .utf8) {
            return uuid
        }
        
        return nil
    }
    
    private static func saveUUIDToKeychain(_ uuid: String) {
        guard let data = uuid.data(using: .utf8) else {
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: uuidKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func resetUUID() -> String {
        let newUUID = UUID().uuidString
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: uuidKey
        ]
        
        SecItemDelete(query as CFDictionary)
        
        saveUUIDToKeychain(newUUID)
        
        return newUUID
    }
} 
