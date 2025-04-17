import Foundation
import Security

/// 用于管理设备UUID的工具类，将UUID存储在Keychain中，确保数据安全且应用卸载后仍然保留
class KeychainUUID {
    
    // Keychain中存储UUID的键
    private static let uuidKey = "com.appflex.device.uuid"
    
    /// 获取设备的唯一标识符。如果之前已经生成并存储了UUID，则返回该值；否则，生成新的UUID，存储并返回
    static func getUUID() -> String {
        // 尝试从Keychain中获取UUID
        if let uuid = getUUIDFromKeychain() {
            return uuid
        }
        
        // 如果Keychain中没有，则生成新的UUID并保存
        let newUUID = UUID().uuidString
        saveUUIDToKeychain(newUUID)
        return newUUID
    }
    
    /// 从Keychain中获取存储的UUID
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
    
    /// 将UUID保存到Keychain
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
        
        // 尝试删除任何现有项（如果存在）
        SecItemDelete(query as CFDictionary)
        
        // 添加新项
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// 重置UUID（生成新的）
    static func resetUUID() -> String {
        let newUUID = UUID().uuidString
        
        // 创建查询以找到现有的UUID项
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: uuidKey
        ]
        
        // 尝试删除现有的UUID
        SecItemDelete(query as CFDictionary)
        
        // 保存新UUID
        saveUUIDToKeychain(newUUID)
        
        return newUUID
    }
} 