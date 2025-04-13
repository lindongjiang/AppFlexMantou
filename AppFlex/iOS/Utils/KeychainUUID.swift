import Foundation
import Security

class KeychainUUID {
    
    // 用于存储在钥匙串中的服务和账户标识符
    private static let service = "com.appflex.deviceid"
    private static let account = "DeviceUUID"
    
    // 生成或获取持久化UUID
    static func getUUID() -> String {
        // 尝试从钥匙串读取UUID
        if let uuid = retrieveUUID() {
            print("从KeyChain检索到现有UUID: \(uuid)")
            return uuid
        }
        
        // 如果钥匙串中没有，则生成一个新的UUID
        let newUUID = UUID().uuidString
        print("生成新的UUID: \(newUUID)")
        
        // 保存到钥匙串
        save(uuid: newUUID)
        
        return newUUID
    }
    
    // 将UUID保存到钥匙串
    private static func save(uuid: String) {
        // 准备查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: uuid.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // 尝试添加新条目
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("UUID成功保存到KeyChain")
        } else if status == errSecDuplicateItem {
            // 如果条目已存在，则更新它
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: uuid.data(using: .utf8)!
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            
            if updateStatus == errSecSuccess {
                print("UUID在KeyChain中更新成功")
            } else {
                print("更新KeyChain中的UUID失败，错误码: \(updateStatus)")
            }
        } else {
            print("保存UUID到KeyChain失败，错误码: \(status)")
        }
    }
    
    // 从钥匙串读取UUID
    private static func retrieveUUID() -> String? {
        // 准备查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let uuid = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                print("从KeyChain检索UUID失败，错误码: \(status)")
            }
            return nil
        }
        
        return uuid
    }
    
    // 从钥匙串删除UUID（如果需要重置）
    static func deleteUUID() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("UUID已从KeyChain中删除")
            return true
        } else {
            print("从KeyChain删除UUID失败，错误码: \(status)")
            return false
        }
    }
} 