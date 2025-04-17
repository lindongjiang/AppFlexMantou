
import SwiftUI
import UIKit


@main
struct AppFlexApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showCalculator = true // 默认显示计算器
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showCalculator {
                    CalculatorView()
                } else {
                    TabbarView()
                }
            }
            .onAppear {
                checkDisguiseMode()
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DisguiseModeChanged"))) { notification in
                if let userInfo = notification.userInfo, let enabled = userInfo["enabled"] as? Bool {
                    showCalculator = enabled
                }
            }
        }
    }
    
    func handleIncomingURL(_ url: URL) {
        
        if url.scheme?.lowercased() == "appflex" && url.host == "udid" {
            if let udid = url.pathComponents.last, !udid.isEmpty {
                
                let userInfo = ["udid": udid]
                NotificationCenter.default.post(
                    name: NSNotification.Name("UDIDCallbackReceived"),
                    object: nil,
                    userInfo: userInfo
                )
                
                globalDeviceUUID = udid
                
                UserDefaults.standard.setValue(udid, forKey: "deviceUDID")
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    private func checkDisguiseMode() {
        ServerController.shared.checkDisguiseMode { shouldShowRealApp in
            DispatchQueue.main.async {
                self.showCalculator = !shouldShowRealApp
            }
        }
    }
}

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        
        if let scheme = url.scheme?.lowercased() {
            if (scheme == "appflex" || scheme == "mantou") && url.host == "udid" {
                if let udid = url.pathComponents.last, !udid.isEmpty {
                    
                    let userInfo = ["udid": udid]
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UDIDCallbackReceived"),
                        object: nil,
                        userInfo: userInfo
                    )
                    
                    globalDeviceUUID = udid
                    
                    UserDefaults.standard.setValue(udid, forKey: "deviceUDID")
                    UserDefaults.standard.synchronize()
                    
                    return true
                }
            }
            
            if scheme == "appflex" {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                
                if url.host == "install" {
                    if let queryItems = components?.queryItems,
                       let appId = queryItems.first(where: { $0.name == "id" })?.value {
                        let userInfo = ["appId": appId]
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AppInstallRequested"),
                            object: nil,
                            userInfo: userInfo
                        )
                        return true
                    }
                } else if url.host == "verify" {
                    if let queryItems = components?.queryItems,
                       let status = queryItems.first(where: { $0.name == "status" })?.value,
                       let appId = queryItems.first(where: { $0.name == "appId" })?.value {
                        let isSuccess = (status == "success")
                        
                        let userInfo: [String: Any] = ["success": isSuccess, "appId": appId]
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CardVerificationResult"),
                            object: nil,
                            userInfo: userInfo
                        )
                        return true
                    }
                } else if url.host == "disguise" {
                    if let queryItems = components?.queryItems,
                       let status = queryItems.first(where: { $0.name == "enabled" })?.value {
                        let isEnabled = (status == "true" || status == "1")
                        
                        let userInfo = ["enabled": isEnabled]
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DisguiseModeChanged"),
                            object: nil,
                            userInfo: userInfo
                        )
                        
                        UserDefaults.standard.setValue(isEnabled, forKey: "disguise_mode_enabled")
                        UserDefaults.standard.synchronize()
                        
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            
            if url.path.contains("/udid/") {
                let components = url.pathComponents
                if let index = components.firstIndex(of: "udid"), index + 1 < components.count {
                    let udid = components[index + 1]
                    
                    let userInfo = ["udid": udid]
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UDIDCallbackReceived"),
                        object: nil,
                        userInfo: userInfo
                    )
                    
                    globalDeviceUUID = udid
                    
                    UserDefaults.standard.setValue(udid, forKey: "deviceUDID")
                    UserDefaults.standard.synchronize()
                    
                    return true
                }
            }
            
            if url.path.contains("/disguise/") {
                let components = url.pathComponents
                if let index = components.firstIndex(of: "disguise"), index + 1 < components.count {
                    let status = components[index + 1]
                    let isEnabled = (status == "enable" || status == "on")
                    
                    let userInfo = ["enabled": isEnabled]
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DisguiseModeChanged"),
                        object: nil,
                        userInfo: userInfo
                    )
                    
                    UserDefaults.standard.setValue(isEnabled, forKey: "disguise_mode_enabled")
                    UserDefaults.standard.synchronize()
                    
                    return true
                }
            }
        }
        return false
    }
}
