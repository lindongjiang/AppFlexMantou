//
//  AppFlexApp.swift
//  AppFlex
//
//  Created by mantou on 2025/4/11.
//

import SwiftUI

@main
struct AppFlexApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            TabbarView()
                .onOpenURL { url in
                    // 处理所有可能的URL格式
                    handleIncomingURL(url)
                }
        }
    }
    
    // 将URL处理逻辑单独提取出来，以便在多个地方使用
    func handleIncomingURL(_ url: URL) {
        print("收到URL: \(url.absoluteString)")
        
        // 检查URL是否为UDID回调
        if url.scheme?.lowercased() == "appflex" && url.host == "udid" {
            if let udid = url.pathComponents.last, !udid.isEmpty {
                print("收到UDID: \(udid)")
                
                // 创建通知，传递UDID
                let userInfo = ["udid": udid]
                NotificationCenter.default.post(
                    name: NSNotification.Name("UDIDCallbackReceived"),
                    object: nil,
                    userInfo: userInfo
                )
                
                // 保存UDID全局变量
                globalDeviceUUID = udid
                
                // 保存UDID到UserDefaults
                UserDefaults.standard.setValue(udid, forKey: "deviceUDID")
                UserDefaults.standard.synchronize()
            }
        }
    }
}

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 在启动时注册自定义URL Scheme处理
        print("应用启动")
        return true
    }
    
    // 处理通过URL Scheme打开应用的情况 - 旧版API
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("通过旧API打开URL: \(url.absoluteString)")
        
        // 检查URL是否为UDID回调
        if url.scheme?.lowercased() == "appflex" && url.host == "udid" {
            if let udid = url.pathComponents.last, !udid.isEmpty {
                print("收到UDID: \(udid)")
                
                // 创建通知，传递UDID
                let userInfo = ["udid": udid]
                NotificationCenter.default.post(
                    name: NSNotification.Name("UDIDCallbackReceived"),
                    object: nil,
                    userInfo: userInfo
                )
                
                // 保存UDID全局变量
                globalDeviceUUID = udid
                
                // 保存UDID到UserDefaults
                UserDefaults.standard.setValue(udid, forKey: "deviceUDID")
                UserDefaults.standard.synchronize()
                
                return true
            }
        }
        return false
    }
    
    // 处理Universal Links - iOS 13及更高版本
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        print("通过Universal Links打开")
        
        // 如果是网页链接
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            print("Universal Link URL: \(url.absoluteString)")
            
            // 如果URL包含UDID参数
            if url.path.contains("/udid/") {
                let components = url.pathComponents
                if let index = components.firstIndex(of: "udid"), index + 1 < components.count {
                    let udid = components[index + 1]
                    print("从Universal Link提取的UDID: \(udid)")
                    
                    // 创建通知，传递UDID
                    let userInfo = ["udid": udid]
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UDIDCallbackReceived"),
                        object: nil,
                        userInfo: userInfo
                    )
                    
                    // 保存UDID全局变量
                    globalDeviceUUID = udid
                    
                    // 保存UDID到UserDefaults
                    UserDefaults.standard.setValue(udid, forKey: "deviceUDID")
                    UserDefaults.standard.synchronize()
                    
                    return true
                }
            }
        }
        return false
    }
}
