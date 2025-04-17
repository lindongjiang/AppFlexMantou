import Foundation

/// 应用安全管理器 - 负责处理所有敏感数据的加密和解密
class AppSecurityManager {
    // 单例
    static let shared = AppSecurityManager()
    
    // 私有初始化方法
    private init() {}
    
    // 获取安装协议前缀 - 在运行时动态生成，不存储明文
    func getInstallProtocol() -> String {
        return StringObfuscator.shared.getAppProtocol()
    }
    
    // 获取API基础URL - 在运行时动态生成，不存储明文
    func getBaseURL() -> String {
        return StringObfuscator.shared.getBaseURL()
    }
    
    // 加密任意字符串
    func encryptString(_ text: String) -> [String: String]? {
        return CryptoUtils.shared.encrypt(plainText: text)
    }
    
    // 解密字符串
    func decryptString(encryptedData: String, iv: String) -> String? {
        return CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv)
    }
    
    // 构建安装URL并加密 - 不存储明文协议
    func buildAndEncryptInstallURL(plistURL: String) -> [String: String]? {
        // 构建完整的URL
        let installURLString = getInstallProtocol() + plistURL
        
        // 加密并返回
        return encryptString(installURLString)
    }
    
    // 处理API路径 - 确保所有API路径都使用加密的基础URL
    func buildAPIURL(path: String) -> String {
        let base = getBaseURL()
        
        if path.hasPrefix("/") {
            return base + path
        } else {
            return base + "/" + path
        }
    }
    
    // 从混淆的字节数组创建字符串
    func stringFromObfuscatedBytes(_ bytes: [Int]) -> String {
        return StringObfuscator.shared.getObfuscatedString(bytes)
    }
} 