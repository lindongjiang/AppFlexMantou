import Foundation

class AppSecurityManager {
    static let shared = AppSecurityManager()
    
    private init() {}
    
    func getInstallProtocol() -> String {
        return StringObfuscator.shared.getAppProtocol()
    }
    
    func getBaseURL() -> String {
        return StringObfuscator.shared.getBaseURL()
    }
    
    func encryptString(_ text: String) -> [String: String]? {
        return CryptoUtils.shared.encrypt(plainText: text)
    }
    
    func decryptString(encryptedData: String, iv: String) -> String? {
        return CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv)
    }
    
    func buildAndEncryptInstallURL(plistURL: String) -> [String: String]? {
        let installURLString = getInstallProtocol() + plistURL
        
        return encryptString(installURLString)
    }
    
    func buildAPIURL(path: String) -> String {
        let base = getBaseURL()
        
        if path.hasPrefix("/") {
            return base + path
        } else {
            return base + "/" + path
        }
    }
    
    func stringFromObfuscatedBytes(_ bytes: [Int]) -> String {
        return StringObfuscator.shared.getObfuscatedString(bytes)
    }
} 
