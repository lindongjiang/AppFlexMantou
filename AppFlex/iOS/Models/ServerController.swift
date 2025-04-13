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
    
    // 主要API基础URL
    private let baseURL = "https://renmai.cloudmantoub.online/api/client"
    
    // 备用API基础URL - 增加多个备用URL以提高成功率
    private let fallbackBaseURLs = [
        "https://renmai.cloudmantoub.online/api/client",
    ]
    
    // 当前使用的URL
    private var currentBaseURL: String
    private var currentURLIndex = 0
    
    private var apiFailureCount = 0
    private let maxFailureCount = 2 // 降低失败阈值，更快切换URL
    
    // UDID管理
    private let udidKey = "custom_device_udid"
    
    // 伪装模式状态
    private var disguiseModeEnabled = true
    private let disguiseModeKey = "disguise_mode_enabled"
    
    private init() {
        // 初始使用主要URL
        currentBaseURL = baseURL
        print("API 服务初始化 - 主API: \(baseURL)")
        print("API 服务初始化 - 备用APIs: \(fallbackBaseURLs)")
        
        // 启动时测试主URL连接
        testMainURLConnection()
        
        // 启动时检查UDID绑定状态
        initializeUDIDBindingStatus()
        
        // 启动时检查伪装模式状态
        checkDisguiseModeOnStartup()
    }
    
    // 启动时测试主URL连接
    private func testMainURLConnection() {
        guard let url = URL(string: "\(baseURL)/ping") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error = error {
                print("主API连接测试失败: \(error.localizedDescription)，将使用备用URL")
                self?.switchToNextURL()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("主API返回非200状态码: \(httpResponse.statusCode)，将使用备用URL")
                self?.switchToNextURL()
                return
            }
            
            print("主API连接测试成功")
        }.resume()
    }
    
    // 切换到下一个URL
    private func switchToNextURL() {
        currentURLIndex = (currentURLIndex + 1) % (fallbackBaseURLs.count + 1)
        
        if currentURLIndex == 0 {
            currentBaseURL = baseURL
            print("切换到主API URL: \(currentBaseURL)")
        } else {
            currentBaseURL = fallbackBaseURLs[currentURLIndex - 1]
            print("切换到备用API URL \(currentURLIndex): \(currentBaseURL)")
        }
        
        apiFailureCount = 0
    }
    
    // 如果API调用失败，切换到备用URL
    private func switchToFallbackURLIfNeeded() {
        apiFailureCount += 1
        
        if apiFailureCount >= maxFailureCount {
            switchToNextURL()
        }
    }
    
    func getAppList(completion: @escaping ([ServerApp]?, Error?) -> Void) {
        guard let url = URL(string: "\(currentBaseURL)/apps") else {
            print("错误：无法构建应用列表URL")
            completion(nil, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }
        
        print("开始请求应用列表：\(url.absoluteString)")
        
        // 创建一个带有超时时间的请求
        var request = URLRequest(url: url)
        request.timeoutInterval = 15 // 15秒超时
        request.cachePolicy = .reloadIgnoringLocalCacheData // 忽略缓存
        
        // 添加用户代理和请求头，使请求更类似于正常浏览器请求
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // 添加重试逻辑
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                print("获取应用列表网络错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                completion(nil, error)
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("应用列表HTTP状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("服务器返回非200状态码: \(httpResponse.statusCode)")
                    self?.switchToFallbackURLIfNeeded()
                    completion(nil, NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误: \(httpResponse.statusCode)"]))
                    return
                }
            }
            
            guard let data = data else {
                print("服务器未返回数据")
                self?.switchToFallbackURLIfNeeded()
                completion(nil, NSError(domain: "No data", code: 0, userInfo: nil))
                return
            }
            
            print("收到服务器响应，数据大小: \(data.count) 字节")
            
            // 打印原始响应数据以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("服务器响应：\(responseString.prefix(500))...")
            }
            
            do {
                // 处理不标准的JSON响应（如果有的话）
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                // 解析服务器返回的应用列表JSON
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    print("成功解析响应JSON")
                    
                    if let success = json["success"] as? Bool {
                        print("响应中的success字段: \(success)")
                        
                        if !success {
                            // 检查错误消息
                            let message = json["message"] as? String ?? "未知错误"
                            print("服务器返回错误: \(message)")
                            self?.switchToFallbackURLIfNeeded()
                            completion(nil, NSError(domain: "API Error", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
                            return
                        }
                    }
                    
                    // 尝试直接获取数据数组（某些API可能直接返回数组）
                    var appsDataArray: [[String: Any]] = []
                    
                    // 检查是否是加密响应格式
                    if let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String {
                        
                        print("检测到加密的应用数据，尝试解密")
                        
                        // 使用CryptoUtils解密数据
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            print("解密成功，数据长度: \(decryptedString.count)")
                            
                            // 尝试将解密后的数据解析为JSON
                            if let decryptedData = decryptedString.data(using: .utf8),
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                
                                print("成功解析解密后的JSON数据")
                                
                                // 检查解密后的数据格式
                                if let decryptedApps = decryptedJson as? [[String: Any]] {
                                    // 直接是应用数组
                                    appsDataArray = decryptedApps
                                    print("解析出 \(appsDataArray.count) 个应用")
                                } else if let nestedData = decryptedJson as? [String: Any],
                                         let appsData = nestedData["data"] as? [[String: Any]] {
                                    // 嵌套在data字段中的应用数组
                                    appsDataArray = appsData
                                    print("从嵌套JSON解析出 \(appsDataArray.count) 个应用")
                                } else {
                                    print("无法识别解密后的数据格式")
                                    self?.switchToFallbackURLIfNeeded()
                                    
                                    // 尝试返回测试应用
                                    let testApps = self?.createTestApps()
                                    if let testApps = testApps, !testApps.isEmpty {
                                        print("返回测试应用数据")
                                        completion(testApps, nil)
                                        return
                                    }
                                    
                                    completion(nil, NSError(domain: "Invalid decrypted data format", code: 0, userInfo: nil))
                                    return
                                }
                            } else {
                                print("无法将解密后的数据解析为JSON")
                                self?.switchToFallbackURLIfNeeded()
                                
                                // 尝试返回测试应用
                                let testApps = self?.createTestApps()
                                if let testApps = testApps, !testApps.isEmpty {
                                    print("返回测试应用数据")
                                    completion(testApps, nil)
                                    return
                                }
                                
                                completion(nil, NSError(domain: "Invalid decrypted data", code: 0, userInfo: nil))
                                return
                            }
                        } else {
                            print("解密失败")
                            self?.switchToFallbackURLIfNeeded()
                            
                            // 尝试返回测试应用
                            let testApps = self?.createTestApps()
                            if let testApps = testApps, !testApps.isEmpty {
                                print("返回测试应用数据")
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
                        // 尝试将json对象重新序列化为数组
                        appsDataArray = castedArray
                    } else if json["id"] != nil {
                        // 可能是单个应用对象，将其放入数组
                        appsDataArray = [json]
                    } else {
                        print("响应JSON中不存在data字段或格式错误")
                        self?.switchToFallbackURLIfNeeded()
                        
                        // 尝试直接创建一个测试应用
                        let testApps = self?.createTestApps()
                        if let testApps = testApps, !testApps.isEmpty {
                            print("返回测试应用数据")
                            completion(testApps, nil)
                            return
                        }
                        
                        completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析应用列表数据"])) 
                        return
                    }
                    
                    print("响应包含 \(appsDataArray.count) 个应用")
                    
                    let apps = appsDataArray.compactMap { appDict -> ServerApp? in
                        guard let id = appDict["id"] as? String,
                              let name = appDict["name"] as? String,
                              let version = appDict["version"] as? String,
                              let icon = appDict["icon"] as? String else {
                            print("应用JSON数据缺少必要字段: \(appDict)")
                            return nil
                        }
                        
                        let pkg = appDict["pkg"] as? String
                        let plist = appDict["plist"] as? String
                        let requiresKey = appDict["requires_key"] as? Int == 1
                        
                        print("Debug: 初始加载应用 - ID: \(id), 名称: \(name), 需要卡密: \(requiresKey)")
                        
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
                    
                    // 重置失败计数
                    self?.apiFailureCount = 0
                    
                    // 如果没有解析到应用，返回测试应用
                    if apps.isEmpty {
                        print("未能解析任何应用，返回测试应用")
                        let testApps = self?.createTestApps() ?? []
                        completion(testApps, nil)
                        return
                    }
                    
                    print("成功解析 \(apps.count) 个应用")
                    completion(apps, nil)
                } else {
                    print("无法将响应解析为JSON")
                    self?.switchToFallbackURLIfNeeded()
                    
                    // 返回测试应用
                    let testApps = self?.createTestApps()
                    if let testApps = testApps, !testApps.isEmpty {
                        print("返回测试应用数据")
                        completion(testApps, nil)
                        return
                    }
                    
                    completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                }
            } catch {
                print("JSON解析错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                
                // 返回测试应用
                let testApps = self?.createTestApps()
                if let testApps = testApps, !testApps.isEmpty {
                    print("返回测试应用数据")
                    completion(testApps, nil)
                    return
                }
                
                completion(nil, error)
            }
        }
    }
    
    // 执行网络请求，支持重试
    private func performRequest(_ request: URLRequest, retryCount: Int, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // 检查是否需要重试
            if (error != nil || (response as? HTTPURLResponse)?.statusCode != 200) && retryCount > 0 {
                print("请求失败，将在1秒后重试，剩余重试次数: \(retryCount - 1)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    self?.performRequest(request, retryCount: retryCount - 1, completion: completion)
                }
                return
            }
            
            completion(data, response, error)
        }.resume()
    }
    
    // 清理API响应数据，处理特殊情况
    private func cleanResponseData(_ data: Data) -> Data {
        // 尝试去除可能的BOM或前导字符
        if let string = String(data: data, encoding: .utf8) {
            // 去除非JSON前导字符
            let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = trimmedString.range(of: "{"), range.lowerBound != trimmedString.startIndex {
                let jsonPart = String(trimmedString[range.lowerBound...])
                return jsonPart.data(using: .utf8) ?? data
            }
        }
        return data
    }
    
    // 创建测试应用数据，以防API失败
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
        // 获取设备UDID
        let udid = getDeviceUDID()
        print("设备标识(实际使用): \(udid)")
        
        // 在URL中添加UDID参数
        guard let encodedUDID = udid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(currentBaseURL)/apps/\(appId)?udid=\(encodedUDID)") else {
            print("错误：无法构建应用详情URL")
            completion(nil, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }
        
        print("开始获取应用详情: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // 使用与getAppList相同的重试逻辑
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                print("获取应用详情网络错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                
                // 如果是测试应用ID，返回测试数据
                if appId.hasPrefix("test") {
                    if let testApp = self?.createTestAppDetail(appId: appId) {
                        completion(testApp, nil)
                        return
                    }
                }
                
                completion(nil, error)
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("应用详情HTTP状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("服务器返回非200状态码: \(httpResponse.statusCode)")
                    self?.switchToFallbackURLIfNeeded()
                    
                    // 如果是测试应用ID，返回测试数据
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
                print("服务器未返回数据")
                self?.switchToFallbackURLIfNeeded()
                
                // 如果是测试应用ID，返回测试数据
                if appId.hasPrefix("test") {
                    if let testApp = self?.createTestAppDetail(appId: appId) {
                        completion(testApp, nil)
                        return
                    }
                }
                
                completion(nil, NSError(domain: "No data", code: 0, userInfo: nil))
                return
            }
            
            print("收到应用详情响应，数据大小: \(data.count) 字节")
            
            // 打印原始响应数据以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("应用详情响应：\(responseString.prefix(500))...")
            }
            
            do {
                // 处理不标准的JSON响应
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    var appData: [String: Any]? = nil
                    
                    // 尝试获取应用数据
                    if let success = json["success"] as? Bool, success {
                        // 检查是否是加密响应格式
                        if let dataObj = json["data"] as? [String: Any],
                           let iv = dataObj["iv"] as? String,
                           let encryptedData = dataObj["data"] as? String {
                            
                            print("检测到加密的应用详情数据，尝试解密")
                            
                            // 使用CryptoUtils解密数据
                            if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                                print("解密成功，数据长度: \(decryptedString.count)")
                                
                                // 尝试将解密后的数据解析为JSON
                                if let decryptedData = decryptedString.data(using: .utf8),
                                   let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                    
                                    print("成功解析解密后的JSON数据")
                                    
                                    // 检查解密后的数据格式
                                    if let jsonDict = decryptedJson as? [String: Any] {
                                        // 直接是应用对象
                                        appData = jsonDict
                                        print("解析出应用详情")
                                    } else if let jsonDict = decryptedJson as? [String: Any],
                                              let appDataObj = jsonDict["data"] as? [String: Any] {
                                        // 嵌套在data字段中的应用对象
                                        appData = appDataObj
                                        print("从嵌套JSON解析出应用详情")
                                    } else {
                                        print("无法识别解密后的应用数据格式")
                                    }
                                } else {
                                    print("无法将解密后的应用详情数据解析为JSON")
                                }
                            } else {
                                print("应用详情解密失败")
                            }
                        } else {
                            appData = json["data"] as? [String: Any]
                        }
                    } else if json["id"] != nil {
                        // 有些API可能直接返回应用对象
                        appData = json
                    }
                    
                    if let appData = appData {
                        // 提取必要字段
                        guard let id = appData["id"] as? String,
                              let name = appData["name"] as? String,
                              let version = appData["version"] as? String,
                              let icon = appData["icon"] as? String else {
                            print("应用详情缺少必要字段")
                            
                            // 如果是测试应用ID，返回测试数据
                            if appId.hasPrefix("test") {
                                if let testApp = self?.createTestAppDetail(appId: appId) {
                                    completion(testApp, nil)
                                    return
                                }
                            }
                            
                            completion(nil, NSError(domain: "Missing required fields", code: 0, userInfo: nil))
                            return
                        }
                        
                        // 提取其他字段，使用默认值避免nil
                        let pkg = appData["pkg"] as? String
                        let plist = appData["plist"] as? String
                        let requiresKey = appData["requires_key"] as? Int == 1
                        
                        // 构建应用对象
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
                        print("无法从响应中提取应用数据")
                        self?.switchToFallbackURLIfNeeded()
                        
                        // 如果是测试应用ID，返回测试数据
                        if appId.hasPrefix("test") {
                            if let testApp = self?.createTestAppDetail(appId: appId) {
                                completion(testApp, nil)
                                return
                            }
                        }
                        
                        completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                    }
                } else {
                    print("无法将应用详情响应解析为JSON")
                    self?.switchToFallbackURLIfNeeded()
                    
                    // 如果是测试应用ID，返回测试数据
                    if appId.hasPrefix("test") {
                        if let testApp = self?.createTestAppDetail(appId: appId) {
                            completion(testApp, nil)
                            return
                        }
                    }
                    
                    completion(nil, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                }
            } catch {
                print("应用详情JSON解析错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                
                // 如果是测试应用ID，返回测试数据
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
    
    // 创建测试应用详情
    private func createTestAppDetail(appId: String) -> ServerApp? {
        let testApps = createTestApps()
        return testApps.first { $0.id == appId }
    }
    
    // 检查应用是否需要进行卡密验证
    func doesAppRequireCardVerification(appId: String, requiresKey: Bool, completion: @escaping (Bool) -> Void) {
        print("Debug: 检查应用是否需要卡密验证 - 应用ID: \(appId), requiresKey: \(requiresKey)")
        
        // 如果应用不需要卡密，直接返回false
        if !requiresKey {
            print("应用不需要卡密验证")
            completion(false)
            return
        }
        
        // 获取当前设备UDID
        let udid = getDeviceUDID()
        print("设备标识(检查卡密需求): \(udid)")
        
        // 直接向服务器查询此UDID是否有权限访问此应用
        checkUDIDBinding(udid: udid) { isBound, bindingData in
            if isBound, let bindingData = bindingData {
                print("服务器确认设备已绑定")
                
                // 检查绑定记录
                if let bindings = bindingData["bindings"] as? [[String: Any]], !bindings.isEmpty {
                    // 检查是否有全局解锁权限
                    let hasGlobalAccess = bindings.contains { binding in
                        if let appId = binding["app_id"], appId is NSNull {
                            print("服务器确认设备有全局解锁权限")
                            return true
                        }
                        return false
                    }
                    
                    // 检查是否有此特定应用的解锁权限
                    let hasSpecificAccess = bindings.contains { binding in
                        if let boundAppId = binding["app_id"] as? String, boundAppId == appId {
                            print("服务器确认设备已解锁特定应用: \(appId)")
                            return true
                        }
                        return false
                    }
                    
                    if hasGlobalAccess || hasSpecificAccess {
                        print("[Debug] 服务器确认应用已解锁: \(appId)")
                        
                        // 确保本地也标记为已解锁状态
                        DispatchQueue.main.async {
                            UserDefaults.standard.set(true, forKey: "app_unlocked_\(appId)")
                            UserDefaults.standard.synchronize()
                            print("[Debug] 已同步本地解锁状态: \(appId)")
                        }
                        
                        completion(false) // 不需要卡密验证
                        return
                    }
                }
            }
            
            print("服务器未确认设备有权访问此应用，需要卡密验证")
            completion(true) // 需要卡密验证
        }
    }
    
    // 验证卡密后不再设置本地标志
    func verifyCard(cardKey: String, appId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(currentBaseURL)/verify") else {
            print("错误：无法构建验证卡密URL")
            completion(false, "无效的URL")
            return
        }
        
        // 获取UDID，确保每次使用相同的值
        let udid = getDeviceUDID()
        print("设备标识(验证卡密): \(udid)")
        
        print("开始验证卡密: \(url.absoluteString)")
        print("[Debug] 开始验证卡密: \(cardKey) 用于应用: \(appId), 设备: \(udid)")
        
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
            print("验证卡密请求参数: \(parameters)")
        } catch {
            print("验证卡密参数序列化失败: \(error.localizedDescription)")
            completion(false, "请求参数错误")
            return
        }
        
        // 使用与其他请求相同的重试逻辑
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                print("验证卡密网络错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                completion(false, "网络错误: \(error.localizedDescription)")
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("验证卡密HTTP状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("服务器返回非200状态码: \(httpResponse.statusCode)")
                    self?.switchToFallbackURLIfNeeded()
                    completion(false, "服务器响应错误: \(httpResponse.statusCode)")
                    return
                }
            }
            
            guard let data = data else {
                print("服务器未返回数据")
                self?.switchToFallbackURLIfNeeded()
                completion(false, "服务器未返回数据")
                return
            }
            
            print("收到验证卡密响应，数据大小: \(data.count) 字节")
            
            // 打印原始响应数据以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("验证卡密响应：\(responseString)")
            }
            
            do {
                // 处理不标准的JSON响应
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    var success = json["success"] as? Bool ?? false
                    var message = json["message"] as? String
                    var plist = json["plist"] as? String  // 提取plist链接
                    
                    // 检查是否是加密响应格式
                    if success && message == nil,
                       let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String {
                        
                        print("检测到加密的验证结果数据，尝试解密")
                        
                        // 使用CryptoUtils解密数据
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            print("解密成功，数据长度: \(decryptedString.count)")
                            
                            // 尝试将解密后的数据解析为JSON
                            if let decryptedData = decryptedString.data(using: .utf8),
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                
                                print("成功解析解密后的验证结果数据")
                                
                                // 从解密后的数据中提取信息
                                if let jsonDict = decryptedJson as? [String: Any] {
                                    if let decryptedSuccess = jsonDict["success"] as? Bool {
                                        success = decryptedSuccess
                                    }
                                    
                                    if let decryptedMessage = jsonDict["message"] as? String {
                                        message = decryptedMessage
                                    }
                                    
                                    // 尝试从解密数据中提取plist链接
                                    if let decryptedPlist = jsonDict["plist"] as? String {
                                        plist = decryptedPlist
                                    }
                                } else {
                                    print("解密后的JSON不是有效的字典格式")
                                }
                            } else {
                                print("无法将解密后的验证结果数据解析为JSON")
                            }
                        } else {
                            print("验证结果解密失败")
                        }
                    }
                    
                    // 如果成功但没有消息，添加默认消息
                    if success && message == nil {
                        message = "卡密验证成功"
                    }
                    
                    if success {
                        print("卡密验证成功")
                        if let msg = message {
                            if msg.contains("解锁所有应用") || msg.contains("访问所有应用") {
                                print("[Debug] 卡密验证成功: 全局解锁")
                            } else {
                                print("[Debug] 卡密验证成功: \(appId)")
                            }
                        }
                    }
                    
                    // 优先返回plist链接，如果有的话
                    let returnMessage = plist ?? message
                    
                    self?.apiFailureCount = 0
                    completion(success, returnMessage)
                } else {
                    print("无法将验证卡密响应解析为JSON")
                    self?.switchToFallbackURLIfNeeded()
                    completion(false, "无效的服务器响应")
                }
            } catch {
                print("验证卡密JSON解析错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                completion(false, "响应解析错误")
            }
        }
    }
    
    func refreshAppDetail(appId: String, completion: @escaping (Bool, Error?) -> Void) {
        // 获取设备UDID
        let udid = getDeviceUDID()
        print("设备标识(刷新应用): \(udid)")
        
        // 在URL中添加UDID参数，并确保正确编码
        guard let encodedUDID = udid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(currentBaseURL)/refresh-app/\(appId)?udid=\(encodedUDID)") else {
            print("错误：无法构建刷新应用URL")
            completion(false, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }
        
        print("开始刷新应用详情: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        // 使用与其他请求相同的重试逻辑
        performRequest(request, retryCount: 3) { [weak self] data, response, error in
            if let error = error {
                print("刷新应用详情网络错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                
                // 如果是测试应用，直接返回成功
                if appId.hasPrefix("test") {
                    completion(true, nil)
                    return
                }
                
                completion(false, error)
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("刷新应用详情HTTP状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("服务器返回非200状态码: \(httpResponse.statusCode)")
                    self?.switchToFallbackURLIfNeeded()
                    
                    // 如果是测试应用，直接返回成功
                    if appId.hasPrefix("test") {
                        completion(true, nil)
                        return
                    }
                    
                    completion(false, NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误: \(httpResponse.statusCode)"]))
                    return
                }
            }
            
            guard let data = data else {
                print("服务器未返回数据")
                self?.switchToFallbackURLIfNeeded()
                
                // 如果是测试应用，直接返回成功
                if appId.hasPrefix("test") {
                    completion(true, nil)
                    return
                }
                
                completion(false, NSError(domain: "No data", code: 0, userInfo: nil))
                return
            }
            
            print("收到刷新应用详情响应，数据大小: \(data.count) 字节")
            
            // 打印原始响应数据以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("刷新应用详情响应：\(responseString)")
            }
            
            do {
                // 处理不标准的JSON响应
                let cleanedData = self?.cleanResponseData(data) ?? data
                
                if let json = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any] {
                    var success = false
                    
                    // 检查是否是加密响应格式
                    if let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String {
                        
                        print("检测到加密的刷新结果数据，尝试解密")
                        
                        // 使用CryptoUtils解密数据
                        if let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv) {
                            print("解密成功，数据长度: \(decryptedString.count)")
                            
                            // 尝试将解密后的数据解析为JSON
                            if let decryptedData = decryptedString.data(using: .utf8),
                               let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) {
                                
                                print("成功解析解密后的刷新结果数据")
                                
                                // 从解密后的数据中提取成功状态
                                if let jsonDict = decryptedJson as? [String: Any] {
                                    if let decryptedSuccess = jsonDict["success"] as? Bool {
                                        success = decryptedSuccess
                                    } else if let status = jsonDict["status"] as? String, status.lowercased() == "success" {
                                        success = true
                                    } else if jsonDict["data"] != nil {
                                        success = true
                                    }
                                } else {
                                    print("解密后的JSON不是有效的字典格式")
                                }
                            } else {
                                print("无法将解密后的刷新结果数据解析为JSON")
                            }
                        } else {
                            print("刷新结果解密失败")
                        }
                    } else {
                        // 尝试解析success字段
                        if let successField = json["success"] as? Bool {
                            success = successField
                        } else if let status = json["status"] as? String, status.lowercased() == "success" {
                            // 某些API可能使用status字段
                            success = true
                        } else if json["data"] != nil {
                            // 如果有数据字段，可能表示成功
                            success = true
                        }
                    }
                    
                    self?.apiFailureCount = 0
                    completion(success, nil)
                } else {
                    print("无法将刷新应用详情响应解析为JSON")
                    self?.switchToFallbackURLIfNeeded()
                    
                    // 如果是测试应用，直接返回成功
                    if appId.hasPrefix("test") {
                        completion(true, nil)
                        return
                    }
                    
                    completion(false, NSError(domain: "Invalid response format", code: 0, userInfo: nil))
                }
            } catch {
                print("刷新应用详情JSON解析错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                
                // 如果是测试应用，直接返回成功
                if appId.hasPrefix("test") {
                    completion(true, nil)
                    return
                }
                
                completion(false, error)
            }
        }
    }
    
    // 获取设备UDID
    func getDeviceUDID() -> String {
        // 优先使用全局标准键 "deviceUDID" 获取 UDID
        if let standardUDID = UserDefaults.standard.string(forKey: "deviceUDID"), !standardUDID.isEmpty {
            return standardUDID
        }
        
        // 其次使用自定义键获取 UDID (兼容旧代码)
        if let customUDID = UserDefaults.standard.string(forKey: udidKey), !customUDID.isEmpty {
            // 同步到标准键
            UserDefaults.standard.set(customUDID, forKey: "deviceUDID")
            UserDefaults.standard.synchronize()
            return customUDID
        }
        
        // 否则使用系统生成的UUID - 直接使用原始格式，不进行格式转换
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            // 保存到标准键
            UserDefaults.standard.set(uuid, forKey: "deviceUDID")
            UserDefaults.standard.synchronize()
            return uuid
        }
        
        let newUUID = UUID().uuidString
        // 保存到标准键
        UserDefaults.standard.set(newUUID, forKey: "deviceUDID")
        UserDefaults.standard.synchronize()
        return newUUID
    }
    
    // 格式化UDID方法不再需要，但保留以避免API兼容性问题
    private func formatUDID(_ udid: String) -> String {
        return udid // 直接返回原始值
    }
    
    // 保存用户输入的UDID
    func saveCustomUDID(_ udid: String) {
        // 同时保存到两个位置
        UserDefaults.standard.set(udid, forKey: udidKey)
        UserDefaults.standard.set(udid, forKey: "deviceUDID")
        UserDefaults.standard.synchronize()
        print("已保存自定义UDID: \(udid)")
    }
    
    // 清除用户输入的UDID
    func clearCustomUDID() {
        // 同时清除两个位置
        UserDefaults.standard.removeObject(forKey: udidKey)
        UserDefaults.standard.removeObject(forKey: "deviceUDID")
        UserDefaults.standard.synchronize()
        print("已清除自定义UDID，将使用系统生成的UUID")
    }
    
    // 检查是否已设置自定义UDID
    func hasCustomUDID() -> Bool {
        if let customUDID = UserDefaults.standard.string(forKey: udidKey), !customUDID.isEmpty {
            return true
        }
        return false
    }
    
    // 获取当前使用的UDID（用于显示）
    func getCurrentUDID() -> String {
        return getDeviceUDID()
    }
    
    // 添加检查UDID绑定状态的方法
    func checkUDIDBinding(udid: String? = nil, completion: @escaping (Bool, [String: Any]?) -> Void) {
        let targetUDID = udid ?? getDeviceUDID()
        print("设备标识(检查绑定): \(targetUDID)")
        
        guard let encodedUDID = targetUDID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(currentBaseURL)/check-udid?udid=\(encodedUDID)") else {
            print("错误：无法构建检查UDID URL")
            completion(false, nil)
            return
        }
        
        print("检查设备授权状态: \(url.absoluteString)")
        print("[Debug] 检查设备授权状态，设备标识: \(targetUDID)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("AppFlex/1.0 iOS/\(UIDevice.current.systemVersion)", forHTTPHeaderField: "User-Agent")
        
        // 使用无重试的简单请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("检查UDID绑定状态网络错误: \(error.localizedDescription)")
                completion(false, nil)
                return
            }
            
            guard let data = data else {
                print("服务器未返回数据")
                completion(false, nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let success = json["success"] as? Bool, success {
                        if let responseData = json["data"] as? [String: Any] {
                            let isBound = responseData["bound"] as? Bool ?? false
                            
                            if isBound {
                                print("设备标识已绑定，可访问应用")
                                
                                // 如果绑定成功，更新全局解锁状态
                                if let bindings = responseData["bindings"] as? [[String: Any]], !bindings.isEmpty {
                                    completion(true, responseData)
                                    return
                                }
                            } else {
                                print("设备标识未绑定，需要验证卡密")
                                print("[Debug] 设备未授权，需要卡密验证")
                            }
                        }
                    }
                }
                
                completion(false, nil)
            } catch {
                print("解析UDID绑定响应JSON失败: \(error.localizedDescription)")
                completion(false, nil)
            }
        }.resume()
    }
    
    // 每次启动应用时打印设备标识，但不再进行本地存储
    private func initializeUDIDBindingStatus() {
        // 获取UDID
        let udid = getDeviceUDID()
        print("设备标识: \(udid)")
        print("[Debug] 设备标识: \(udid)")
    }
    
    // MARK: - 伪装模式管理
    
    /// 启动时检查伪装模式状态
    private func checkDisguiseModeOnStartup() {
        // 首先检查本地保存的伪装模式状态
        if let savedDisguiseMode = UserDefaults.standard.object(forKey: disguiseModeKey) as? Bool {
            disguiseModeEnabled = savedDisguiseMode
            print("从本地加载伪装模式状态: \(disguiseModeEnabled ? "启用" : "禁用")")
        }
        
        // 然后从服务器获取最新状态，使用新的检查方法而不是原来的基本方法
        intelligentDisguiseCheck { [weak self] shouldShowRealApp in
            DispatchQueue.main.async {
                self?.disguiseModeEnabled = !shouldShowRealApp
                // 保存到本地
                UserDefaults.standard.set(self?.disguiseModeEnabled, forKey: self?.disguiseModeKey ?? "")
                UserDefaults.standard.synchronize()
                
                print("从服务器更新伪装模式状态: \(self?.disguiseModeEnabled == true ? "启用" : "禁用")")
                
                // 如果不需要伪装模式，且当前正在显示计算器，则切换到真实APP
                if !shouldShowRealApp {
                    // 通知伪装模式状态已更改
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DisguiseModeChanged"),
                        object: nil,
                        userInfo: ["enabled": self?.disguiseModeEnabled ?? true]
                    )
                }
            }
        }
    }
    
    /// 检查是否应该显示真实应用
    /// - Parameter completion: 回调，如果为true，应显示真实应用；如果为false，应继续显示计算器
    func checkDisguiseMode(completion: @escaping (Bool) -> Void) {
        // 获取设备UDID
        let udid = getDeviceUDID()
        
        // 构建请求
        // 仅为伪装模式检查使用专用URL - 更新为新的API端点
        let disguiseCheckURL = "https://uni.cloudmantoub.online/disguise_check.php"
        guard let url = URL(string: disguiseCheckURL) else {
            print("错误: 无效的伪装模式检查URL")
            // 当URL无效时，使用本地保存的状态
            completion(!disguiseModeEnabled)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "udid": udid,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("构建伪装模式检查请求体错误: \(error.localizedDescription)")
            // 使用本地保存的状态
            completion(!disguiseModeEnabled)
            return
        }
        
        // 发送请求
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // 处理错误
            if let error = error {
                print("伪装模式检查网络错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                // 使用本地保存的状态
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                print("伪装模式检查无效的HTTP响应")
                self?.switchToFallbackURLIfNeeded()
                // 使用本地保存的状态
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            // 检查HTTP状态码
            guard httpResponse.statusCode == 200 else {
                print("伪装模式检查HTTP错误: \(httpResponse.statusCode)")
                self?.switchToFallbackURLIfNeeded()
                // 使用本地保存的状态
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            // 解析响应数据
            guard let data = data else {
                print("伪装模式检查没有数据")
                self?.switchToFallbackURLIfNeeded()
                // 使用本地保存的状态
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let responseData = json["data"] as? [String: Any],
                   let disguiseMode = responseData["disguise_enabled"] as? Bool {
                    
                    print("伪装模式服务器返回: \(disguiseMode ? "启用" : "禁用")")
                    
                    // 更新本地状态
                    DispatchQueue.main.async {
                        self?.disguiseModeEnabled = disguiseMode
                        // 保存到本地以备离线使用
                        UserDefaults.standard.set(disguiseMode, forKey: self?.disguiseModeKey ?? "")
                        UserDefaults.standard.synchronize()
                    }
                    
                    // 重置API失败计数
                    self?.apiFailureCount = 0
                    
                    // 返回是否应显示真实应用
                    completion(!disguiseMode)
                } else {
                    print("伪装模式检查解析错误: 无效JSON结构")
                    self?.switchToFallbackURLIfNeeded()
                    // 使用本地保存的状态
                    completion(!(self?.disguiseModeEnabled ?? true))
                }
            } catch {
                print("伪装模式检查JSON解析错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                // 使用本地保存的状态
                completion(!(self?.disguiseModeEnabled ?? true))
            }
        }.resume()
    }
    
    /// 高级伪装模式检查，基于多种因素决定是否应显示真实应用
    /// - Parameters:
    ///   - forceCheck: 是否强制检查服务器，忽略缓存
    ///   - cacheTimeout: 缓存有效时间（秒）
    ///   - completion: 回调，true表示应显示真实应用，false表示应显示计算器
    func checkDisguiseModeAdvanced(forceCheck: Bool = false, cacheTimeout: TimeInterval = 300, completion: @escaping (Bool) -> Void) {
        // 获取上次检查时间
        let lastCheckTime = UserDefaults.standard.object(forKey: "last_disguise_check_time") as? Date
        let currentTime = Date()
        
        // 检查是否可以使用缓存
        if !forceCheck, 
           let lastCheck = lastCheckTime, 
           currentTime.timeIntervalSince(lastCheck) < cacheTimeout,
           let cachedValue = UserDefaults.standard.object(forKey: disguiseModeKey) as? Bool {
            print("使用缓存的伪装模式状态: \(cachedValue ? "启用" : "禁用")")
            completion(!cachedValue)
            return
        }
        
        // 获取设备UDID
        let udid = getDeviceUDID()
        
        // 获取当前位置信息
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
        
        // 高级接口不存在，使用基本接口代替
        let disguiseCheckURL = "https://uni.cloudmantoub.online/disguise_check.php"
        guard let url = URL(string: disguiseCheckURL) else {
            print("错误: 无效的高级伪装模式检查URL")
            // 当URL无效时，使用本地保存的状态
            completion(!disguiseModeEnabled)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10 // 设置较短的超时时间
        
        // 构建请求体，包含更多信息
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
            print("构建高级伪装模式检查请求体错误: \(error.localizedDescription)")
            // 使用本地保存的状态
            completion(!disguiseModeEnabled)
            return
        }
        
        // 添加请求计时
        let requestStartTime = Date()
        
        // 发送请求
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // 计算请求花费的时间
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            print("伪装模式高级检查请求耗时: \(requestDuration)秒")
            
            // 保存最后检查时间
            UserDefaults.standard.set(currentTime, forKey: "last_disguise_check_time")
            
            // 处理错误
            if let error = error {
                print("高级伪装模式检查网络错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
                
                // 网络错误时的智能判断：
                // 1. 如果是连接超时，可能是在封闭网络环境，倾向于保持伪装
                // 2. 如果是服务器拒绝连接，可能是服务器故障，使用本地缓存
                let errorCode = (error as NSError).code
                if errorCode == NSURLErrorTimedOut || errorCode == NSURLErrorCannotConnectToHost {
                    print("网络环境可能受限，保持伪装模式")
                    
                    // 更新本地状态为伪装开启
                    DispatchQueue.main.async {
                        self?.disguiseModeEnabled = true
                        UserDefaults.standard.set(true, forKey: self?.disguiseModeKey ?? "")
                        UserDefaults.standard.synchronize()
                    }
                    
                    completion(false) // 保持伪装
                    return
                }
                
                // 其他错误使用本地状态
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                print("高级伪装模式检查无效的HTTP响应")
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            // 检查HTTP状态码
            guard httpResponse.statusCode == 200 else {
                print("高级伪装模式检查HTTP错误: \(httpResponse.statusCode)")
                self?.switchToFallbackURLIfNeeded()
                
                // 特殊状态码处理
                if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                    print("服务器拒绝请求，可能是安全措施，保持伪装模式")
                    
                    // 更新本地状态为伪装开启
                    DispatchQueue.main.async {
                        self?.disguiseModeEnabled = true
                        UserDefaults.standard.set(true, forKey: self?.disguiseModeKey ?? "")
                        UserDefaults.standard.synchronize()
                    }
                    
                    completion(false) // 保持伪装
                    return
                }
                
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            // 解析响应数据
            guard let data = data else {
                print("高级伪装模式检查没有数据")
                self?.switchToFallbackURLIfNeeded()
                completion(!(self?.disguiseModeEnabled ?? true))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 检查是否是加密响应
                    if let dataObj = json["data"] as? [String: Any],
                       let iv = dataObj["iv"] as? String,
                       let encryptedData = dataObj["data"] as? String,
                       let decryptedString = CryptoUtils.shared.decrypt(encryptedData: encryptedData, iv: iv),
                       let decryptedData = decryptedString.data(using: .utf8),
                       let decryptedJson = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] {
                        
                        print("检测到加密的高级伪装检查响应，成功解密")
                        
                        // 处理解密后的JSON
                        if let disguiseMode = decryptedJson["disguise_enabled"] as? Bool {
                            print("高级伪装模式服务器返回(加密): \(disguiseMode ? "启用" : "禁用")")
                            
                            // 处理可能包含的特殊指令
                            if let expirationTime = decryptedJson["expiration_time"] as? TimeInterval {
                                let expirationDate = Date(timeIntervalSince1970: expirationTime)
                                print("伪装模式状态过期时间: \(expirationDate)")
                                UserDefaults.standard.set(expirationDate, forKey: "disguise_mode_expiration")
                            }
                            
                            // 更新本地状态
                            DispatchQueue.main.async {
                                self?.disguiseModeEnabled = disguiseMode
                                UserDefaults.standard.set(disguiseMode, forKey: self?.disguiseModeKey ?? "")
                                UserDefaults.standard.synchronize()
                            }
                            
                            // 重置API失败计数
                            self?.apiFailureCount = 0
                            
                            // 返回是否应显示真实应用
                            completion(!disguiseMode)
                            return
                        }
                    } else if let success = json["success"] as? Bool, 
                              success,
                              let responseData = json["data"] as? [String: Any],
                              let disguiseMode = responseData["disguise_enabled"] as? Bool {
                        
                        print("高级伪装模式服务器返回: \(disguiseMode ? "启用" : "禁用")")
                        
                        // 处理可能包含的特殊指令
                        if let expirationTime = responseData["expiration_time"] as? TimeInterval {
                            let expirationDate = Date(timeIntervalSince1970: expirationTime)
                            print("伪装模式状态过期时间: \(expirationDate)")
                            UserDefaults.standard.set(expirationDate, forKey: "disguise_mode_expiration")
                        }
                        
                        // 更新本地状态
                        DispatchQueue.main.async {
                            self?.disguiseModeEnabled = disguiseMode
                            UserDefaults.standard.set(disguiseMode, forKey: self?.disguiseModeKey ?? "")
                            UserDefaults.standard.synchronize()
                        }
                        
                        // 重置API失败计数
                        self?.apiFailureCount = 0
                        
                        // 返回是否应显示真实应用
                        completion(!disguiseMode)
                        return
                    } else {
                        print("高级伪装模式检查解析错误: 无效JSON结构")
                        self?.switchToFallbackURLIfNeeded()
                    }
                } else {
                    print("高级伪装模式检查解析错误: 无效JSON格式")
                    self?.switchToFallbackURLIfNeeded()
                }
            } catch {
                print("高级伪装模式检查JSON解析错误: \(error.localizedDescription)")
                self?.switchToFallbackURLIfNeeded()
            }
            
            // 如果所有解析尝试都失败，使用本地保存的状态
            completion(!(self?.disguiseModeEnabled ?? true))
        }.resume()
    }
    
    /// 根据当前网络环境智能判断是否应该显示真实应用
    /// - Parameter completion: 回调，true表示应显示真实应用，false表示应显示计算器
    func intelligentDisguiseCheck(completion: @escaping (Bool) -> Void) {
        // 首先检查本地缓存的过期时间
        if let expirationDate = UserDefaults.standard.object(forKey: "disguise_mode_expiration") as? Date,
           expirationDate > Date() {
            // 缓存未过期，使用本地状态
            let disguiseMode = UserDefaults.standard.bool(forKey: disguiseModeKey)
            print("使用有效期内的缓存状态: \(disguiseMode ? "伪装" : "真实应用")")
            completion(!disguiseMode)
            return
        }
        
        // 检查当前网络状态
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            monitor.cancel() // 获得结果后取消监控
            
            let isWiFi = path.usesInterfaceType(.wifi)
            let isCellular = path.usesInterfaceType(.cellular)
            let status = path.status
            
            print("网络状态: WiFi=\(isWiFi), 蜂窝=\(isCellular), 状态=\(status)")
            
            // 智能决策逻辑
            if path.status == .unsatisfied {
                // 没有网络连接，使用本地缓存
                print("无网络连接，使用本地缓存")
                let disguiseMode = UserDefaults.standard.bool(forKey: self?.disguiseModeKey ?? "")
                completion(!disguiseMode)
                return
            }
            
            // 在WiFi环境下，通过服务器检查
            if isWiFi {
                self?.checkDisguiseModeAdvanced { shouldShowRealApp in
                    completion(shouldShowRealApp)
                }
                return
            }
            
            // 在蜂窝网络下，先检查是否是已知的安全网络
            if isCellular {
                // 获取移动运营商信息
                let networkInfo = CTTelephonyNetworkInfo()
                var carrierName = "未知"
                
                if #available(iOS 13.0, *) {
                    if let carrier = networkInfo.serviceSubscriberCellularProviders?.values.first {
                        carrierName = carrier.carrierName ?? "未知"
                    }
                } else {
                    // 旧版iOS使用不同的API
                    if let carrier = networkInfo.subscriberCellularProvider {
                        carrierName = carrier.carrierName ?? "未知"
                    }
                }
                
                print("移动运营商: \(carrierName)")
                
                // 默认在蜂窝网络下通过服务器检查
                self?.checkDisguiseModeAdvanced { shouldShowRealApp in
                    completion(shouldShowRealApp)
                }
                return
            }
            
            // 其他情况，使用标准检查
            self?.checkDisguiseMode(completion: completion)
        }
        
        monitor.start(queue: queue)
    }
} 
