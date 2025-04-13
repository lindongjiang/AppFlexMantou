import Foundation
import CommonCrypto

class CryptoUtils {
    static let shared = CryptoUtils()
    
    // 从 Mantou 项目中提取的解密密钥
    private let key = "5486abfd96080e09e82bb2ab93258bde19d069185366b5aa8d38467835f2e7aa"
    
    private init() {}
    
    // 添加一个方法来验证IV和加密数据的格式
    func validateFormat(encryptedData: String, iv: String) -> (Bool, String?) {
        // 检查IV和加密数据是否为有效的十六进制字符串
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        
        if iv.rangeOfCharacter(from: hexCharSet.inverted) != nil {
            return (false, "IV 不是有效的十六进制字符串")
        }
        
        if encryptedData.rangeOfCharacter(from: hexCharSet.inverted) != nil {
            return (false, "加密数据不是有效的十六进制字符串")
        }
        
        return (true, nil)
    }
    
    // 将十六进制字符串转换为Data
    private func hexStringToData(_ hexString: String) -> Data? {
        var data = Data(capacity: hexString.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: hexString, options: [], range: NSRange(hexString.startIndex..., in: hexString)) { match, _, _ in
            let byteString = (hexString as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        return data
    }
    
    // 解密方法 - 使用AES-256-CBC
    func decrypt(encryptedData: String, iv: String) -> String? {
        // 检查输入数据格式
        let (valid, error) = validateFormat(encryptedData: encryptedData, iv: iv)
        if !valid {
            print("解密数据格式无效: \(error ?? "未知错误")")
            return nil
        }
        
        guard let keyData = hexStringToData(key),
              let ivData = hexStringToData(iv),
              let encryptedBytes = hexStringToData(encryptedData) else {
            print("数据转换失败")
            return nil
        }
        
        // 创建输出缓冲区
        let decryptedLength = encryptedBytes.count
        var decryptedBytes = [UInt8](repeating: 0, count: decryptedLength)
        
        // 创建密钥缓冲区
        let keyLength = keyData.count
        let keyBytes = [UInt8](keyData)
        
        // 创建初始化向量缓冲区
        let ivBytes = [UInt8](ivData)
        
        // 加密操作上下文
        var cryptorRef: CCCryptorRef? = nil
        
        // 创建解密器
        let status = CCCryptorCreate(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            keyBytes, keyLength,
            ivBytes,
            &cryptorRef
        )
        
        guard status == kCCSuccess else {
            print("创建解密器失败，错误码: \(status)")
            return nil
        }
        
        var decryptedBytesLength = 0
        let encryptedBytesLength = encryptedBytes.count
        let encryptedBytesPointer = [UInt8](encryptedBytes)
        
        // 执行解密
        let updateStatus = CCCryptorUpdate(
            cryptorRef,
            encryptedBytesPointer, encryptedBytesLength,
            &decryptedBytes, decryptedLength,
            &decryptedBytesLength
        )
        
        guard updateStatus == kCCSuccess else {
            print("解密更新失败，错误码: \(updateStatus)")
            CCCryptorRelease(cryptorRef)
            return nil
        }
        
        var finalDecryptedBytesLength = 0
        
        // 完成解密
        let finalStatus = CCCryptorFinal(
            cryptorRef,
            &decryptedBytes[decryptedBytesLength],
            decryptedLength - decryptedBytesLength,
            &finalDecryptedBytesLength
        )
        
        CCCryptorRelease(cryptorRef)
        
        guard finalStatus == kCCSuccess else {
            print("解密完成失败，错误码: \(finalStatus)")
            return nil
        }
        
        // 合并解密结果
        let totalDecryptedLength = decryptedBytesLength + finalDecryptedBytesLength
        
        // 处理PKCS7填充
        if totalDecryptedLength > 0 {
            let paddingByte = decryptedBytes[totalDecryptedLength - 1]
            let paddingLength = Int(paddingByte)
            
            if paddingLength > 0 && paddingLength <= kCCBlockSizeAES128 && totalDecryptedLength >= paddingLength {
                // 验证每个填充字节是否相同
                var isValidPadding = true
                for i in (totalDecryptedLength - paddingLength)..<totalDecryptedLength {
                    if decryptedBytes[i] != paddingByte {
                        isValidPadding = false
                        break
                    }
                }
                
                if isValidPadding {
                    let actualLength = totalDecryptedLength - paddingLength
                    let decryptedData = Data(bytes: decryptedBytes, count: actualLength)
                    if let decryptedString = String(data: decryptedData, encoding: .utf8) {
                        return decryptedString
                    }
                }
            }
        }
        
        // 如果无法去除填充或转换为字符串，则返回全部数据
        let decryptedData = Data(bytes: decryptedBytes, count: totalDecryptedLength)
        return String(data: decryptedData, encoding: .utf8)
    }
} 