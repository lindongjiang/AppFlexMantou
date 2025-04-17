import Foundation

/// 字符串混淆工具
/// 使用更安全的方式存储和访问敏感字符串
class StringObfuscator {
    static let shared = StringObfuscator()
    
    private init() {}
    
    /// 对字符串进行混淆处理
    /// - Parameter input: 原始字符串
    /// - Returns: 混淆后的字节数组
    func obfuscate(_ input: String) -> [UInt8] {
        let data = input.data(using: .utf8) ?? Data()
        let key = generateKey(for: input)
        
        var result = [UInt8](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = data[i] ^ key[i % key.count]
        }
        
        return result
    }
    
    /// 从混淆的字节数组恢复原始字符串
    /// - Parameter bytes: 混淆后的字节数组
    /// - Returns: 原始字符串
    func deobfuscate(_ bytes: [UInt8], with seed: String) -> String {
        let key = generateKey(for: seed)
        
        var result = [UInt8](repeating: 0, count: bytes.count)
        for i in 0..<bytes.count {
            result[i] = bytes[i] ^ key[i % key.count]
        }
        
        return String(data: Data(result), encoding: .utf8) ?? ""
    }
    
    /// 基于输入生成一个唯一的密钥
    private func generateKey(for input: String) -> [UInt8] {
        let seed = abs(input.hashValue)
        var key = [UInt8]()
        
        for i in 0..<16 {
            let value = UInt8((seed >> (i * 8 % 64)) & 0xFF)
            key.append(value)
        }
        
        return key
    }
    
    /// 将整数数组转换为字符串
    func bytesToString(_ bytes: [Int]) -> String {
        let data = Data(bytes.map { UInt8($0) })
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// 获取一个混淆字符串的真实值
    /// - Parameter obfuscatedData: 混淆后的整数数组
    /// - Returns: 解混淆后的字符串
    func getObfuscatedString(_ obfuscatedData: [Int], with seed: String = "appflex") -> String {
        let bytes = obfuscatedData.map { UInt8($0) }
        return String(data: Data(bytes), encoding: .utf8) ?? ""
    }
}

/// 为访问器方法添加扩展，让使用更简单
extension StringObfuscator {
    /// 常用域名和URL的安全获取方法
    func getBaseURL() -> String {
        return getObfuscatedString([104, 116, 116, 112, 115, 58, 47, 47, 114, 101, 110, 109, 97, 105, 46, 99, 108, 111, 117, 100, 109, 97, 110, 116, 111, 117, 98, 46, 111, 110, 108, 105, 110, 101])
    }
    
    /// 获取资源配置URL
    func getResourceConfigURL() -> String {
        let domain = getObfuscatedString([117, 110, 105, 46, 99, 108, 111, 117, 100, 109, 97, 110, 116, 111, 117, 98, 46, 111, 110, 108, 105, 110, 101])
        let path = getObfuscatedString([119, 101, 98, 115, 111, 117, 114, 99, 101, 46, 106, 115, 111, 110])
        let protocol1 = getObfuscatedString([104, 116, 116, 112, 115, 58, 47, 47])
        
        return protocol1 + domain + "/" + path
    }
    
    /// 获取社交链接配置URL
    func getSocialConfigURL() -> String {
        let domain = getObfuscatedString([117, 110, 105, 46, 99, 108, 111, 117, 100, 109, 97, 110, 116, 111, 117, 98, 46, 111, 110, 108, 105, 110, 101])
        let path = getObfuscatedString([109, 97, 110, 116, 111, 117, 46, 106, 115, 111, 110])
        let protocol1 = getObfuscatedString([104, 116, 116, 112, 115, 58, 47, 47])
        
        return protocol1 + domain + "/" + path
    }
    
    /// 获取应用协议前缀
    func getAppProtocol() -> String {
        let scheme1 = getObfuscatedString([105, 116, 109, 115, 45, 115, 101, 114, 118, 105, 99, 101, 115])
        let scheme2 = getObfuscatedString([58, 47, 47])
        let queryPrefix = getObfuscatedString([63])
        let actionStr = getObfuscatedString([97, 99, 116, 105, 111, 110, 61])
        let downloadStr = getObfuscatedString([100, 111, 119, 110, 108, 111, 97, 100, 45, 109, 97, 110, 105, 102, 101, 115, 116])
        let urlParam = getObfuscatedString([38, 117, 114, 108, 61])
        
        return scheme1 + scheme2 + queryPrefix + actionStr + downloadStr + urlParam
    }
} 