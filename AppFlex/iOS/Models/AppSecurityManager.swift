import Foundation

/// 应用安全管理器 - 负责处理所有敏感字符串的加密和解密
class AppSecurityManager {
    // 单例
    static let shared = AppSecurityManager()
    
    // 私有初始化方法
    private init() {}
    
    // 协议和域名常量 - 使用ASCII码存储，避免明文
    private let scheme1 = [105, 116, 109, 115, 45, 115, 101, 114, 118, 105, 99, 101, 115] 
    private let scheme2 = [58, 47, 47] 
    private let actionStr = [97, 99, 116, 105, 111, 110, 61] 
    private let downloadStr = [100, 111, 119, 110, 108, 111, 97, 100, 45, 109, 97, 110, 105, 102, 101, 115, 116] 
    private let urlParam = [38, 117, 114, 108, 61] 
    private let queryPrefix = [63] 
    private let baseHost = [104, 116, 116, 112, 115, 58, 47, 47, 114, 101, 110, 109, 97, 105, 46, 99, 108, 111, 117, 100, 109, 97, 110, 116, 111, 117, 98, 46, 111, 110, 108, 105, 110, 101] 
    
    // 获取安装协议前缀 - 在运行时动态生成，不存储明文
    func getInstallProtocol() -> String {
        // 转换为UInt8数组
        let part1Data = Data(scheme1.map { UInt8($0) })
        let part2Data = Data(scheme2.map { UInt8($0) })
        let part3Data = Data(queryPrefix.map { UInt8($0) })
        let part4Data = Data(actionStr.map { UInt8($0) })
        let part5Data = Data(downloadStr.map { UInt8($0) })
        let part6Data = Data(urlParam.map { UInt8($0) })
        
        // 转换为字符串
        let part1 = String(data: part1Data, encoding: .ascii) ?? ""
        let part2 = String(data: part2Data, encoding: .ascii) ?? ""
        let part3 = String(data: part3Data, encoding: .ascii) ?? ""
        let part4 = String(data: part4Data, encoding: .ascii) ?? ""
        let part5 = String(data: part5Data, encoding: .ascii) ?? ""
        let part6 = String(data: part6Data, encoding: .ascii) ?? ""
        
        return part1 + part2 + part3 + part4 + part5 + part6
    }
    
    // 获取API基础URL - 在运行时动态生成，不存储明文
    func getBaseURL() -> String {
        let baseHostData = Data(baseHost.map { UInt8($0) })
        return String(data: baseHostData, encoding: .ascii) ?? ""
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
    
    // 混淆字符串方法 - 简单转换明文为对应的ASCII数组表示
    func getObfuscatedBytes(for text: String) -> [Int] {
        return Array(text.utf8).map { Int($0) }
    }
    
    // 从混淆的字节数组创建字符串
    func stringFromObfuscatedBytes(_ bytes: [Int]) -> String {
        let data = Data(bytes.map { UInt8($0) })
        return String(data: data, encoding: .utf8) ?? ""
    }
} 