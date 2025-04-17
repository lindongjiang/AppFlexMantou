import Foundation
import UIKit

struct ServerApp {
    let id: String
    let name: String
    let version: String
    let icon: String
    let pkg: String?
    let plist: String?
    let requiresKey: Bool
    let requiresUnlock: Bool
    let isUnlocked: Bool
    
    init(id: String, name: String, version: String, icon: String, pkg: String?, plist: String?, requiresKey: Bool, requiresUnlock: Bool, isUnlocked: Bool) {
        self.id = id
        self.name = name
        self.version = version
        self.icon = icon
        self.pkg = pkg
        self.plist = plist
        self.requiresKey = requiresKey
        self.requiresUnlock = requiresUnlock
        self.isUnlocked = isUnlocked
    }
}

class ServerController {
    static let shared = ServerController()
    
    private let baseURL = "https://renmai.cloudmantoub.online/api/client"
    
    private let fallbackBaseURLs = [
        "https://api.cloudmantoub.online/api/client",
        "https://store.cloudmantoub.online/api/client",
        "https://apps.cloudmantoub.online/api/client"
    ]
    
    private var currentBaseURL: String
    private var currentURLIndex = 0
    
    private var apiFailureCount = 0
    private let maxFailureCount = 2 // 降低失败阈值，更快切换URL
    
    private let udidKey = "custom_device_udid"
    
    private init() {
        currentBaseURL = baseURL
        
        testMainURLConnection()
    }
    
    private func testMainURLConnection() {
        guard let url = URL(string: "\(baseURL)/ping") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error = error {
                self?.switchToNextURL()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                self?.switchToNextURL()
                return
            }
            
        }.resume()
    }
    
    private func switchToNextURL() {
        currentURLIndex = (currentURLIndex + 1) % (fallbackBaseURLs.count + 1)
        
        if currentURLIndex == 0 {
            currentBaseURL = baseURL
        } else {
            currentBaseURL = fallbackBaseURLs[currentURLIndex - 1]
        }
        
        apiFailureCount = 0
    }
    
    private func switchToFallbackURLIfNeeded() {
        apiFailureCount += 1
        
        if apiFailureCount >= maxFailureCount {
            switchToNextURL()
        }
    }
    
    func getAppList(completion: @escaping ([ServerApp]?, Error?) -> Void) {
        guard let url = URL(string: "\(currentBaseURL)/apps") else {
            completion(nil, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }
        
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15 // 15秒超时
        request.cachePolicy = .reloadIgnoringLocalCacheData // 忽略缓存
        
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                self?.switchToFallbackURLIfNeeded()
                completion(nil, error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if httpResponse.statusCode != 200 {
                    self?.switchToFallbackURLIfNeeded()
                    completion(nil, NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误: \(httpResponse.statusCode)"]))
                    return
                }
            }
            
            guard let data = data else {
                self?.switchToFallbackURLIfNeeded()
                completion(nil, NSError(domain: "No data", code: 0, userInfo: nil))
                return
            }
            
            
            if let responseString = String(data: data, encoding: .utf8) {
            }
            
            do {
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    
                    if let success = json["success"] as? Bool {
                        
                        if !success {
                            let message = json["message"] as? String ?? "未知错误"
                            self?.switchToFallbackURLIfNeeded()
                            completion(nil, NSError(domain: "API Error", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
                            return
                        }
                    }
                    
                    var appsDataArray: [[String: Any]] = []
                    
                    if let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String {
                        
                        
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            
                            if let decryptedData = decryptedString.data(using: .utf8),
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                
                                
                                if let decryptedApps = decryptedJson as? [[String: Any]] {
                                    appsDataArray = decryptedApps
                                } else if let nestedData = decryptedJson as? [String: Any],
                                          let appsData = nestedData["data"] as? [[String: Any]] {
                                    appsDataArray = appsData
                                } else {
                                    self?.switchToFallbackURLIfNeeded()
                                    
                                    let testApps = self?.createTestApps()
                                    if let testApps = testApps, !testApps.isEmpty {
                                        completion(testApps, nil)
                                        return
                                    }
                                    
                                    completion(nil, NSError(domain: "Invalid decrypted data format", code: 0, userInfo: nil))
                                    return
                                }
                            } else {
                                self?.switchToFallbackURLIfNeeded()
                                
                                let testApps = self?.createTestApps()
                                if let testApps = testApps, !testApps.isEmpty {
                                    completion(testApps, nil)
                                    return
                                }
                                
                                completion(nil, NSError(domain: "Invalid decrypted data", code: 0, userInfo: nil))
                                return
                            }
                        } else {
                            self?.switchToFallbackURLIfNeeded()
                            
                            let testApps = self?.createTestApps()
                            if let testApps = testApps, !testApps.isEmpty {
                                completion(testApps, nil)
                                return
                            }
                            
                            completion(nil, NSError(domain: "Decryption failed", code: 0, userInfo: nil))
                            return
                        }
                    } else if let appsData = json["data"] as? [[String: Any]] {
                        appsDataArray = appsData
                    } else if let directData = json as? NSArray, 
                              let castedArray = directData as? [[String: Any]] {
                        appsDataArray = castedArray
                    } else if json["id"] != nil {
                        appsDataArray = [json]
                    } else {
                        self?.switchToFallbackURLIfNeeded()
                        
                        let testApps = self?.createTestApps()
                        if let testApps = testApps, !testApps.isEmpty {
                            completion(testApps, nil)
                            return
                        }
                        
                        completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析应用列表数据"])) 
                        return
                    }
                    
                    
                    let apps = appsDataArray.compactMap { appDict -> ServerApp? in
                        guard let id = appDict["id"] as? String,
                              let name = appDict["name"] as? String,
                              let version = appDict["version"] as? String,
                              let icon = appDict["icon"] as? String else {
                            return nil
                        }
                        
                        let pkg = appDict["pkg"] as? String
                        let plist = appDict["plist"] as? String
                        let requiresKey = appDict["requires_key"] as? Int == 1
                        
                        let isUnlockedLocally = UserDefaults.standard.bool(forKey: "app_unlocked_\(id)")
                        
                        return ServerApp(
                            id: id,
                            name: name,
                            version: version,
                            icon: icon,
                            pkg: pkg,
                            plist: plist,
                            requiresKey: requiresKey,
                            requiresUnlock: requiresKey,
                            isUnlocked: isUnlockedLocally
                        )
                    }
                    
                    self?.apiFailureCount = 0
                    
                    if apps.isEmpty {
                        let testApps = self?.createTestApps() ?? []
                        completion(testApps, nil)
                        return
                    }
                    
                    completion(apps, nil)
                } else {
                    self?.switchToFallbackURLIfNeeded()
                    
                    let testApps = self?.createTestApps()
                    if let testApps = testApps, !testApps.isEmpty {
                        completion(testApps, nil)
                        return
                    }
                    
                    completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                }
            } catch {
                self?.switchToFallbackURLIfNeeded()
                
                let testApps = self?.createTestApps()
                if let testApps = testApps, !testApps.isEmpty {
                    completion(testApps, nil)
                    return
                }
                
                completion(nil, error)
            }
        }
    }
    
    private func performRequest(_ request: URLRequest, retryCount: Int, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if (error != nil || (response as? HTTPURLResponse)?.statusCode != 200) && retryCount > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    self?.performRequest(request, retryCount: retryCount - 1, completion: completion)
                }
                return
            }
            
            completion(data, response, error)
        }.resume()
    }
    
    private func cleanResponseData(_ data: Data) -> Data {
        if let string = String(data: data, encoding: .utf8) {
            let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = trimmedString.range(of: "{"), range.lowerBound != trimmedString.startIndex {
                let jsonPart = String(trimmedString[range.lowerBound...])
                return jsonPart.data(using: .utf8) ?? data
            }
        }
        return data
    }
    
    private func createTestApps() -> [ServerApp] {
        let testIcons = [
            "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/c2/c6/d8/c2c6d885-4a33-29b9-dac0-b229c0f8b845/AppIcon-1x_U007emarketing-0-7-0-85-220.png/246x0w.webp",
            "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/dd/fa/5f/ddfa5f1c-a4e1-4625-84c6-7fc6c8a2f02d/AppIcon-0-0-1x_U007emarketing-0-0-0-7-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/246x0w.webp",
            "https://is1-ssl.mzstatic.com/image/thumb/Purple116/v4/01/80/e1/0180e1aa-8203-c7f4-ff20-4452d3df5cf1/AppIcon-0-0-1x_U007emarketing-0-0-0-7-0-0-sRGB-0-0-0-GLES2_U002c0-512MB-85-220-0-0.png/246x0w.webp"
        ]
        
        return [
            ServerApp(
                id: "test1",
                name: "测试应用1",
                version: "1.0.0",
                icon: testIcons[0],
                pkg: nil,
                plist: nil,
                requiresKey: false,
                requiresUnlock: false,
                isUnlocked: true
            ),
            ServerApp(
                id: "test2",
                name: "测试应用2",
                version: "2.0.0",
                icon: testIcons[1],
                pkg: nil,
                plist: nil,
                requiresKey: true,
                requiresUnlock: true,
                isUnlocked: false
            ),
            ServerApp(
                id: "test3",
                name: "测试应用3",
                version: "3.0.0",
                icon: testIcons[2],
                pkg: nil,
                plist: nil,
                requiresKey: false,
                requiresUnlock: false,
                isUnlocked: true
            )
        ]
    }
    
    func getAppDetail(appId: String, completion: @escaping (ServerApp?, Error?) -> Void) {
        guard let url = URL(string: "\(currentBaseURL)/app/\(appId)") else {
            completion(nil, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }
        
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                self?.switchToFallbackURLIfNeeded()
                
                if appId.hasPrefix("test") {
                    if let testApp = self?.createTestAppDetail(appId: appId) {
                        completion(testApp, nil)
                        return
                    }
                }
                
                completion(nil, error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if httpResponse.statusCode != 200 {
                    self?.switchToFallbackURLIfNeeded()
                    
                    if appId.hasPrefix("test") {
                        if let testApp = self?.createTestAppDetail(appId: appId) {
                            completion(testApp, nil)
                            return
                        }
                    }
                    
                    completion(nil, NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误: \(httpResponse.statusCode)"]))
                    return
                }
            }
            
            guard let data = data else {
                self?.switchToFallbackURLIfNeeded()
                
                if appId.hasPrefix("test") {
                    if let testApp = self?.createTestAppDetail(appId: appId) {
                        completion(testApp, nil)
                        return
                    }
                }
                
                completion(nil, NSError(domain: "No data", code: 0, userInfo: nil))
                return
            }
            
            
            if let responseString = String(data: data, encoding: .utf8) {
            }
            
            do {
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    var appData: [String: Any]? = nil
                    
                    if let success = json["success"] as? Bool, success {
                        if let dataObj = json["data"] as? [String: Any],
                           let iv = dataObj["iv"] as? String,
                           let encryptedData = dataObj["data"] as? String {
                            
                            
                            if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                                
                                if let decryptedData = decryptedString.data(using: .utf8),
                                   let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                    
                                    
                                    if let decryptedApp = decryptedJson as? [String: Any] {
                                        appData = decryptedApp
                                    } else if let nestedData = decryptedJson as? [String: Any],
                                             let appDataObj = nestedData["data"] as? [String: Any] {
                                        appData = appDataObj
                                    } else {
                                    }
                                } else {
                                }
                            } else {
                            }
                        } else {
                            appData = json["data"] as? [String: Any]
                        }
                    } else if json["id"] != nil {
                        appData = json
                    }
                    
                    if let appData = appData {
                        guard let id = appData["id"] as? String,
                              let name = appData["name"] as? String else {
                            
                            if appId.hasPrefix("test") {
                                if let testApp = self?.createTestAppDetail(appId: appId) {
                                    completion(testApp, nil)
                                    return
                                }
                            }
                            
                            completion(nil, NSError(domain: "Missing required fields", code: 0, userInfo: nil))
                            return
                        }
                        
                        let version = appData["version"] as? String ?? "1.0"
                        let icon = appData["icon"] as? String ?? "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/c2/c6/d8/c2c6d885-4a33-29b9-dac0-b229c0f8b845/AppIcon-1x_U007emarketing-0-7-0-85-220.png/246x0w.webp"
                        let pkg = appData["pkg"] as? String
                        let plist = appData["plist"] as? String
                        let requiresKey = appData["requires_key"] as? Int == 1
                        
                        let app = ServerApp(
                            id: id,
                            name: name,
                            version: version,
                            icon: icon,
                            pkg: pkg,
                            plist: plist,
                            requiresKey: requiresKey,
                            requiresUnlock: requiresKey,
                            isUnlocked: UserDefaults.standard.bool(forKey: "app_unlocked_\(id)")
                        )
                        
                        self?.apiFailureCount = 0
                        completion(app, nil)
                    } else {
                        self?.switchToFallbackURLIfNeeded()
                        
                        if appId.hasPrefix("test") {
                            if let testApp = self?.createTestAppDetail(appId: appId) {
                                completion(testApp, nil)
                                return
                            }
                        }
                        
                        completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                    }
                } else {
                    self?.switchToFallbackURLIfNeeded()
                    
                    if appId.hasPrefix("test") {
                        if let testApp = self?.createTestAppDetail(appId: appId) {
                            completion(testApp, nil)
                            return
                        }
                    }
                    
                    completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                }
            } catch {
                self?.switchToFallbackURLIfNeeded()
                
                if appId.hasPrefix("test") {
                    if let testApp = self?.createTestAppDetail(appId: appId) {
                        completion(testApp, nil)
                        return
                    }
                }
                
                completion(nil, error)
            }
        }
    }
    
    private func createTestAppDetail(appId: String) -> ServerApp? {
        let testApps = createTestApps()
        return testApps.first { $0.id == appId }
    }
    
    func verifyCard(cardKey: String, appId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(currentBaseURL)/verify-card") else {
            completion(false, "无效的URL")
            return
        }
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        let parameters: [String: Any] = [
            "card_key": cardKey,
            "app_id": appId,
            "udid": getDeviceUDID()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(false, "请求参数错误")
            return
        }
        
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                self?.switchToFallbackURLIfNeeded()
                completion(false, "网络错误: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if httpResponse.statusCode != 200 {
                    self?.switchToFallbackURLIfNeeded()
                    completion(false, "服务器响应错误: \(httpResponse.statusCode)")
                    return
                }
            }
            
            guard let data = data else {
                self?.switchToFallbackURLIfNeeded()
                completion(false, "服务器未返回数据")
                return
            }
            
            
            if let responseString = String(data: data, encoding: .utf8) {
            }
            
            do {
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    var success = json["success"] as? Bool ?? false
                    var message = json["message"] as? String
                    
                    if success && message == nil,
                       let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String {
                        
                        
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            
                            if let decryptedData = decryptedString.data(using: .utf8),
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] {
                                
                                
                                if let decryptedSuccess = decryptedJson["success"] as? Bool {
                                    success = decryptedSuccess
                                }
                                
                                if let decryptedMessage = decryptedJson["message"] as? String {
                                    message = decryptedMessage
                                }
                            } else {
                            }
                        } else {
                        }
                    }
                    
                    if success && message == nil {
                        message = "卡密验证成功"
                    }
                    
                    if success {
                        UserDefaults.standard.set(true, forKey: "app_unlocked_\(appId)")
                        UserDefaults.standard.synchronize()
                    }
                    
                    self?.apiFailureCount = 0
                    completion(success, message)
                } else {
                    self?.switchToFallbackURLIfNeeded()
                    completion(false, "无效的服务器响应")
                }
            } catch {
                self?.switchToFallbackURLIfNeeded()
                completion(false, "响应解析错误")
            }
        }
    }
    
    func refreshAppDetail(appId: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = URL(string: "\(currentBaseURL)/refresh-app/\(appId)") else {
            completion(false, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                self?.switchToFallbackURLIfNeeded()
                
                if appId.hasPrefix("test") {
                    completion(true, nil)
                    return
                }
                
                completion(false, error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if httpResponse.statusCode != 200 {
                    self?.switchToFallbackURLIfNeeded()
                    
                    if appId.hasPrefix("test") {
                        completion(true, nil)
                        return
                    }
                    
                    completion(false, NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误: \(httpResponse.statusCode)"]))
                    return
                }
            }
            
            guard let data = data else {
                self?.switchToFallbackURLIfNeeded()
                
                if appId.hasPrefix("test") {
                    completion(true, nil)
                    return
                }
                
                completion(false, NSError(domain: "No data", code: 0, userInfo: nil))
                return
            }
            
            
            if let responseString = String(data: data, encoding: .utf8) {
            }
            
            do {
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    var success = false
                    
                    if let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String {
                        
                        
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            
                            if let decryptedData = decryptedString.data(using: .utf8),
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] {
                                
                                
                                if let decryptedSuccess = decryptedJson["success"] as? Bool {
                                    success = decryptedSuccess
                                } else if let status = decryptedJson["status"] as? String, status.lowercased() == "success" {
                                    success = true
                                } else if decryptedJson["data"] != nil {
                                    success = true
                                }
                            } else {
                            }
                        } else {
                        }
                    } else {
                        if let successField = json["success"] as? Bool {
                            success = successField
                        } else if let status = json["status"] as? String, status.lowercased() == "success" {
                            success = true
                        } else if json["data"] != nil {
                            success = true
                        }
                    }
                    
                    self?.apiFailureCount = 0
                    completion(success, nil)
                } else {
                    self?.switchToFallbackURLIfNeeded()
                    
                    if appId.hasPrefix("test") {
                        completion(true, nil)
                        return
                    }
                    
                    completion(false, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                }
            } catch {
                self?.switchToFallbackURLIfNeeded()
                
                if appId.hasPrefix("test") {
                    completion(true, nil)
                    return
                }
                
                completion(false, error)
            }
        }
    }
    
    func getDeviceUDID() -> String {
        if let customUDID = UserDefaults.standard.string(forKey: udidKey), !customUDID.isEmpty {
            return customUDID
        }
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
    
    func saveCustomUDID(_ udid: String) {
        UserDefaults.standard.set(udid, forKey: udidKey)
        UserDefaults.standard.synchronize()
    }
    
    func clearCustomUDID() {
        UserDefaults.standard.removeObject(forKey: udidKey)
        UserDefaults.standard.synchronize()
    }
    
    func hasCustomUDID() -> Bool {
        if let customUDID = UserDefaults.standard.string(forKey: udidKey), !customUDID.isEmpty {
            return true
        }
        return false
    }
    
    func getCurrentUDID() -> String {
        return getDeviceUDID()
    }
} 
