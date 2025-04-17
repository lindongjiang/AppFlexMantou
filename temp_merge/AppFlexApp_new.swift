
import SwiftUI

@main
struct AppFlexApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            TabbarView()
                .onOpenURL { url in
                    handleIncomingURL(url)
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
}

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
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
                
                return true
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
        }
        return false
    }
}
