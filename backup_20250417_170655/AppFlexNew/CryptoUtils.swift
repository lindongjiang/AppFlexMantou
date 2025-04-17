import Foundation
import CommonCrypto

class CryptoUtils {
    static let shared = CryptoUtils()
    
    private let key = "5486abfd96080e09e82bb2ab93258bde19d069185366b5aa8d38467835f2e7aa"
    
    private init() {}
    
    func validateFormat(encryptedData: String, iv: String) -> (Bool, String?) {
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        
        if iv.rangeOfCharacter(from: hexCharSet.inverted) != nil {
            return (false, "IV 不是有效的十六进制字符串")
        }
        
        if encryptedData.rangeOfCharacter(from: hexCharSet.inverted) != nil {
            return (false, "加密数据不是有效的十六进制字符串")
        }
        
        return (true, nil)
    }
    
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
    
    func decrypt(encryptedData: String, iv: String) -> String? {
        let (valid, error) = validateFormat(encryptedData: encryptedData, iv: iv)
        if !valid {
            return nil
        }
        
        guard let keyData = hexStringToData(key),
              let ivData = hexStringToData(iv),
              let encryptedBytes = hexStringToData(encryptedData) else {
            return nil
        }
        
        let decryptedLength = encryptedBytes.count
        var decryptedBytes = [UInt8](repeating: 0, count: decryptedLength)
        
        let keyLength = keyData.count
        let keyBytes = [UInt8](keyData)
        
        let ivBytes = [UInt8](ivData)
        
        var cryptorRef: CCCryptorRef? = nil
        
        let status = CCCryptorCreate(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            keyBytes, keyLength,
            ivBytes,
            &cryptorRef
        )
        
        guard status == kCCSuccess else {
            return nil
        }
        
        var decryptedBytesLength = 0
        let encryptedBytesLength = encryptedBytes.count
        let encryptedBytesPointer = [UInt8](encryptedBytes)
        
        let updateStatus = CCCryptorUpdate(
            cryptorRef,
            encryptedBytesPointer, encryptedBytesLength,
            &decryptedBytes, decryptedLength,
            &decryptedBytesLength
        )
        
        guard updateStatus == kCCSuccess else {
            CCCryptorRelease(cryptorRef)
            return nil
        }
        
        var finalDecryptedBytesLength = 0
        
        let finalStatus = CCCryptorFinal(
            cryptorRef,
            &decryptedBytes[decryptedBytesLength],
            decryptedLength - decryptedBytesLength,
            &finalDecryptedBytesLength
        )
        
        CCCryptorRelease(cryptorRef)
        
        guard finalStatus == kCCSuccess else {
            return nil
        }
        
        let totalDecryptedLength = decryptedBytesLength + finalDecryptedBytesLength
        
        if totalDecryptedLength > 0 {
            let paddingByte = decryptedBytes[totalDecryptedLength - 1]
            let paddingLength = Int(paddingByte)
            
            if paddingLength > 0 && paddingLength <= kCCBlockSizeAES128 && totalDecryptedLength >= paddingLength {
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
        
        let decryptedData = Data(bytes: decryptedBytes, count: totalDecryptedLength)
        return String(data: decryptedData, encoding: .utf8)
    }
} 
