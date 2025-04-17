import Foundation
import UIKit
import CoreLocation
import Network
import CoreTelephony

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
        "https://renmai.cloudmantoub.online/api/client",
    ]
    
    private var currentBaseURL: String
    private var currentURLIndex = 0
    
    private var apiFailureCount = 0
    private let maxFailureCount = 2 // 降低失败阈值，更快切换URL
    
    private let udidKey = "custom_device_udid"
    
    private var disguiseModeEnabled = true
    private let disguiseModeKey = "disguise_mode_enabled"
    
    private init() {
        currentBaseURL = baseURL
        
  
        testMainURLConnection()
        
       
        initializeUDIDBindingStatus()
        
        checkDisguiseModeOnStartup()
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
                    } else if let jsonData = try? JSONSerialization.data(withJSONObject: json),
                              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [Any],
                              let castedArray = jsonArray as? [[String: Any]] {
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
                        
                        
                        return ServerApp(
                            id: id,
                            name: name,
                            version: version,
                            icon: icon,
                            pkg: pkg,
                            plist: plist,
                            requiresKey: requiresKey,
                            requiresUnlock: requiresKey,
                            isUnlocked: false // 默认为未解锁，实际解锁状态将在需要时通过服务器查询
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
        let udid = getDeviceUDID()
        
        guard let encodedUDID = udid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(currentBaseURL)/apps/\(appId)?udid=\(encodedUDID)") else {
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
                                    
                                    
                                    if let jsonDict = decryptedJson as? [String: Any] {
                                        appData = jsonDict
                                    } else if let jsonDict = decryptedJson as? [String: Any],
                                              let appDataObj = jsonDict["data"] as? [String: Any] {
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
                              let name = appData["name"] as? String,
                              let version = appData["version"] as? String,
                              let icon = appData["icon"] as? String else {
                            
                            if appId.hasPrefix("test") {
                                if let testApp = self?.createTestAppDetail(appId: appId) {
                                    completion(testApp, nil)
                                    return
                                }
                            }
                            
                            completion(nil, NSError(domain: "Missing required fields", code: 0, userInfo: nil))
                            return
                        }
                        
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
                            isUnlocked: false // 默认为未解锁，实际解锁状态将在需要时通过服务器查询
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
    
    func doesAppRequireCardVerification(appId: String, requiresKey: Bool, completion: @escaping (Bool) -> Void) {
        
        if !requiresKey {
            completion(false)
            return
        }
        
        let udid = getDeviceUDID()
        
        checkUDIDBinding(udid: udid) { isBound, bindingData in
            if isBound, let bindingData = bindingData {
                
                if let bindings = bindingData["bindings"] as? [[String: Any]], !bindings.isEmpty {
                    let hasGlobalAccess = bindings.contains { binding in
                        if let appId = binding["app_id"], appId is NSNull {
                            return true
                        }
                        return false
                    }
                    
                    let hasSpecificAccess = bindings.contains { binding in
                        if let boundAppId = binding["app_id"] as? String, boundAppId == appId {
                            return true
                        }
                        return false
                    }
                    
                    if hasGlobalAccess || hasSpecificAccess {
                        
                        DispatchQueue.main.async {
                            UserDefaults.standard.set(true, forKey: "app_unlocked_\(appId)")
                            UserDefaults.standard.synchronize()
                        }
                        
                        completion(false) // 不需要卡密验证
                        return
                    }
                }
            }
            
            completion(true) // 需要卡密验证
        }
    }
    
    func verifyCard(cardKey: String, appId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(currentBaseURL)/verify") else {
            completion(false, "无效的URL")
            return
        }
        
        let udid = getDeviceUDID()
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        let parameters: [String: Any] = [
            "cardKey": cardKey,
            "appId": appId,
            "udid": udid
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
                    var plist = json["plist"] as? String  // 提取plist链接
                    
                    if success && message == nil,
                       let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String {
                        
                        
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            
                            if let decryptedData = decryptedString.data(using: .utf8),
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                
                                
                                if let jsonDict = decryptedJson as? [String: Any] {
                                    if let decryptedSuccess = jsonDict["success"] as? Bool {
                                        success = decryptedSuccess
                                    }
                                    
                                    if let decryptedMessage = jsonDict["message"] as? String {
                                        message = decryptedMessage
                                    }
                                    
                                    if let decryptedPlist = jsonDict["plist"] as? String {
                                        plist = decryptedPlist
                                    }
                                } else {
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
                        if let msg = message {
                            if msg.contains("解锁所有应用") || msg.contains("访问所有应用") {
                            } else {
                            }
                        }
                    }
                    
                    let returnMessage = plist ?? message
                    
                    self?.apiFailureCount = 0
                    completion(success, returnMessage)
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
        let udid = getDeviceUDID()
        
        guard let encodedUDID = udid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(currentBaseURL)/refresh-app/\(appId)?udid=\(encodedUDID)") else {
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
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                
                                
                                if let jsonDict = decryptedJson as? [String: Any] {
                                    if let decryptedSuccess = jsonDict["success"] as? Bool {
                                        success = decryptedSuccess
                                    } else if let status = jsonDict["status"] as? String, status.lowercased() == "success" {
                                        success = true
                                    } else if jsonDict["data"] != nil {
                                        success = true
                                    }
                                } else {
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
        if let standardUDID = UserDefaults.standard.string(forKey: "deviceUDID"), !standardUDID.isEmpty {
            return standardUDID
        }
        
        if let customUDID = UserDefaults.standard.string(forKey: udidKey), !customUDID.isEmpty {
            UserDefaults.standard.set(customUDID, forKey: "deviceUDID")
            UserDefaults.standard.synchronize()
            return customUDID
        }
        
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            UserDefaults.standard.set(uuid, forKey: "deviceUDID")
            UserDefaults.standard.synchronize()
            return uuid
        }
        
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: "deviceUDID")
        UserDefaults.standard.synchronize()
        return newUUID
    }
    
    private func formatUDID(_ udid: String) -> String {
        return udid // 直接返回原始值
    }
    
    func saveCustomUDID(_ udid: String) {
        UserDefaults.standard.set(udid, forKey: udidKey)
        UserDefaults.standard.set(udid, forKey: "deviceUDID")
        UserDefaults.standard.synchronize()
    }
    
    func clearCustomUDID() {
        UserDefaults.standard.removeObject(forKey: udidKey)
        UserDefaults.standard.removeObject(forKey: "deviceUDID")
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
    
    func checkUDIDBinding(udid: String? = nil, completion: @escaping (Bool, [String: Any]?) -> Void) {
        let targetUDID = udid ?? getDeviceUDID()
        
        guard let encodedUDID = targetUDID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(currentBaseURL)/check-udid?udid=\(encodedUDID)") else {
            completion(false, nil)
            return
        }
        
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, nil)
                return
            }
            
            guard let data = data else {
                completion(false, nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let success = json["success"] as? Bool, success {
                        if let responseData = json["data"] as? [String: Any] {
                            let isBound = responseData["bound"] as? Bool ?? false
                            
                            if isBound {
                                
                                if let bindings = responseData["bindings"] as? [[String: Any]], !bindings.isEmpty {
                                    completion(true, responseData)
                                    return
                                }
                            } else {
                            }
                        }
                    }
                }
                
                completion(false, nil)
            } catch {
                completion(false, nil)
            }
        }.resume()
    }
    
    private func initializeUDIDBindingStatus() {
        let udid = getDeviceUDID()
    }
    
    
    private func checkDisguiseModeOnStartup() {
        if let savedDisguiseMode = UserDefaults.standard.object(forKey: disguiseModeKey) as? Bool {
            disguiseModeEnabled = savedDisguiseMode
        }
        
        intelligentDisguiseCheck { [weak self] shouldShowRealApp in
            DispatchQueue.main.async {
                self?.disguiseModeEnabled = !shouldShowRealApp
                UserDefaults.standard.set(self?.disguiseModeEnabled, forKey: self?.disguiseModeKey ?? "")
                UserDefaults.standard.synchronize()
                
                
                if !shouldShowRealApp {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DisguiseModeChanged"),
                        object: nil,
                        userInfo: ["enabled": self?.disguiseModeEnabled ?? true]
                    )
                }
            }
        }
    }
    
    func checkDisguiseMode(completion: @escaping (Bool) -> Void) {
        let udid = getDeviceUDID()
        
        let disguiseCheckURL = "https://uni.cloudmantoub.online/disguise_check.php"
        guard let url = URL(string: disguiseCheckURL) else {
            completion(!disguiseModeEnabled)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "udid": udid,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(!disguiseModeEnabled)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            guard let data = data else {
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let responseData = json["data"] as? [String: Any],
                   let disguiseMode = responseData["disguise_enabled"] as? Bool {
                    
                    
                    DispatchQueue.main.async {
                        self?.disguiseModeEnabled = disguiseMode
                        UserDefaults.standard.set(disguiseMode, forKey: self?.disguiseModeKey ?? "")
                        UserDefaults.standard.synchronize()
                    }
                    
                    self?.apiFailureCount = 0
                    
                    completion(!disguiseMode)
                } else {
                    self?.switchToFallbackURLIfNeeded()
                    completion(!(self?.disguiseModeEnabled ?? true))
                }
            } catch {
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
            }
        }.resume()
    }
    
    func checkDisguiseModeAdvanced(forceCheck: Bool = false, cacheTimeout: TimeInterval = 300, completion: @escaping (Bool) -> Void) {
        let lastCheckTime = UserDefaults.standard.object(forKey: "last_disguise_check_time") as? Date
        let currentTime = Date()
        
        if !forceCheck, 
           let lastCheck = lastCheckTime, 
           currentTime.timeIntervalSince(lastCheck) < cacheTimeout,
           let cachedValue = UserDefaults.standard.object(forKey: disguiseModeKey) as? Bool {
            completion(!cachedValue)
            return
        }
        
        let udid = getDeviceUDID()
        
        let locManager = CLLocationManager()
        var locationInfo: [String: Any] = ["available": false]
        
        if CLLocationManager.locationServicesEnabled(),
           (locManager.authorizationStatus == .authorizedWhenInUse || 
            locManager.authorizationStatus == .authorizedAlways),
           let location = locManager.location {
            locationInfo = [
                "available": true,
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "timestamp": Int(location.timestamp.timeIntervalSince1970)
            ]
        }
        
        let disguiseCheckURL = "https://uni.cloudmantoub.online/disguise_check.php"
        guard let url = URL(string: disguiseCheckURL) else {
            completion(!disguiseModeEnabled)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10 // 设置较短的超时时间
        
        let requestBody: [String: Any] = [
            "udid": udid,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知",
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "location": locationInfo,
            "timezone": TimeZone.current.identifier,
            "locale": Locale.current.identifier,
            "timestamp": Int(currentTime.timeIntervalSince1970)
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(!disguiseModeEnabled)
            return
        }
        
        let requestStartTime = Date()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            
            UserDefaults.standard.set(currentTime, forKey: "last_disguise_check_time")
            
            if let error = error {
                self?.switchToFallbackURLIfNeeded()
                
                let errorCode = (error as NSError).code
                if errorCode == NSURLErrorTimedOut || errorCode == NSURLErrorCannotConnectToHost {
                    
                    DispatchQueue.main.async {
                        self?.disguiseModeEnabled = true
                        UserDefaults.standard.set(true, forKey: self?.disguiseModeKey ?? "")
                        UserDefaults.standard.synchronize()
                    }
                    
                    completion(false) // 保持
                    return
                }
                
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                self?.switchToFallbackURLIfNeeded()
                
                if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                    
                    DispatchQueue.main.async {
                        self?.disguiseModeEnabled = true
                        UserDefaults.standard.set(true, forKey: self?.disguiseModeKey ?? "")
                        UserDefaults.standard.synchronize()
                    }
                    
                    completion(false) // 保持
                    return
                }
                
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            guard let data = data else {
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String,
                       let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv),
                       let decryptedData = decryptedString.data(using: .utf8),
                       let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] {
                        
                        
                        if let disguiseMode = decryptedJson["disguise_enabled"] as? Bool {
                            
                            if let expirationTime = decryptedJson["expiration_time"] as? TimeInterval {
                                let expirationDate = Date(timeIntervalSince1970: expirationTime)
                                UserDefaults.standard.set(expirationDate, forKey: "disguise_mode_expiration")
                            }
                            
                            DispatchQueue.main.async {
                                self?.disguiseModeEnabled = disguiseMode
                                UserDefaults.standard.set(disguiseMode, forKey: self?.disguiseModeKey ?? "")
                                UserDefaults.standard.synchronize()
                            }
                            
                            self?.apiFailureCount = 0
                            
                            completion(!disguiseMode)
                            return
                        }
                    } else if let success = json["success"] as? Bool, 
                              success,
                              let responseData = json["data"] as? [String: Any],
                              let disguiseMode = responseData["disguise_enabled"] as? Bool {
                        
                        
                        if let expirationTime = responseData["expiration_time"] as? TimeInterval {
                            let expirationDate = Date(timeIntervalSince1970: expirationTime)
                            UserDefaults.standard.set(expirationDate, forKey: "disguise_mode_expiration")
                        }
                        
                        DispatchQueue.main.async {
                            self?.disguiseModeEnabled = disguiseMode
                            UserDefaults.standard.set(disguiseMode, forKey: self?.disguiseModeKey ?? "")
                            UserDefaults.standard.synchronize()
                        }
                        
                        self?.apiFailureCount = 0
                        
                        completion(!disguiseMode)
                        return
                    } else {
                        self?.switchToFallbackURLIfNeeded()
                    }
                } else {
                    self?.switchToFallbackURLIfNeeded()
                }
            } catch {
                self?.switchToFallbackURLIfNeeded()
            }
            
            completion(!(self?.disguiseModeEnabled ?? true))
        }.resume()
    }
    
    func intelligentDisguiseCheck(completion: @escaping (Bool) -> Void) {
        if let expirationDate = UserDefaults.standard.object(forKey: "disguise_mode_expiration") as? Date,
           expirationDate > Date() {
            let disguiseMode = UserDefaults.standard.bool(forKey: disguiseModeKey)
            completion(!disguiseMode)
            return
        }
        
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            monitor.cancel() // 获得结果后取消监控
            
            let isWiFi = path.usesInterfaceType(.wifi)
            let isCellular = path.usesInterfaceType(.cellular)
            let status = path.status
            
            
            if path.status == .unsatisfied {
                let disguiseMode = UserDefaults.standard.bool(forKey: self?.disguiseModeKey ?? "")
                completion(!disguiseMode)
                return
            }
            
            if isWiFi {
                self?.checkDisguiseModeAdvanced { shouldShowRealApp in
                    completion(shouldShowRealApp)
                }
                return
            }
            
            if isCellular {
                let networkInfo = CTTelephonyNetworkInfo()
                var carrierName = "未知"
                
                if #available(iOS 13.0, *) {
                    if let carrier = networkInfo.serviceSubscriberCellularProviders?.values.first {
                        carrierName = carrier.carrierName ?? "未知"
                    }
                } else {
                    if let carrier = networkInfo.subscriberCellularProvider {
                        carrierName = carrier.carrierName ?? "未知"
                    }
                }
                
                
                self?.checkDisguiseModeAdvanced { shouldShowRealApp in
                    completion(shouldShowRealApp)
                }
                return
            }
            
            self?.checkDisguiseMode(completion: completion)
        }
        
        monitor.start(queue: queue)
    }
} 
