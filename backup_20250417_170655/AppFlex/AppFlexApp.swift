//
//  AppFlexApp.swift
//  AppFlex
//
//  Created by mantou on 2025/4/11.
//

import SwiftUI
import UIKit

// 注释掉这个全局变量声明，因为它在StoreCollectionViewController.swift中已经定义
// var globalDeviceUUID: String?

@main
struct AppFlexApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showCalculator = true // 默认显示计算器
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showCalculator {
                    // 显示计算器界面
                    CalculatorView()
                } else {
                    // 显示真实应用
                    TabbarView()
                }
            }
            .onAppear {
                // 检查伪装模式状态
                checkDisguiseMode()
            }
            .onOpenURL { url in
                // 处理所有可能的URL格式
                handleIncomingURL(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DisguiseModeChanged"))) { notification in
                // 当伪装模式状态改变时，更新界面
                if let userInfo = notification.userInfo, let enabled = userInfo["enabled"] as? Bool {
                    showCalculator = enabled
                }
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
    
    // 检查是否应该显示计算器伪装
    private func checkDisguiseMode() {
        // 使用 ServerController 检查伪装模式状态
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
        // 在启动时注册自定义URL Scheme处理
        print("应用启动")
        return true
    }
    
    // 处理通过URL Scheme打开应用的情况 - 旧版API
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("通过旧API打开URL: \(url.absoluteString)")
        
        // 直接处理mantou和appflex协议
        // 这种方法不依赖反射和其他类，更可靠
        
        // 检查URL协议
        if let scheme = url.scheme?.lowercased() {
            // 检查URL是否为UDID回调
            if (scheme == "appflex" || scheme == "mantou") && url.host == "udid" {
                if let udid = url.pathComponents.last, !udid.isEmpty {
                    print("收到\(scheme)协议UDID: \(udid)")
                    
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
            
            // 处理appflex协议的其他功能
            if scheme == "appflex" {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                
                if url.host == "install" {
                    // 处理应用安装链接
                    if let queryItems = components?.queryItems,
                       let appId = queryItems.first(where: { $0.name == "id" })?.value {
                        print("请求安装应用ID: \(appId)")
                        // 发送安装应用通知
                        let userInfo = ["appId": appId]
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AppInstallRequested"),
                            object: nil,
                            userInfo: userInfo
                        )
                        return true
                    }
                } else if url.host == "verify" {
                    // 处理卡密验证结果
                    if let queryItems = components?.queryItems,
                       let status = queryItems.first(where: { $0.name == "status" })?.value,
                       let appId = queryItems.first(where: { $0.name == "appId" })?.value {
                        let isSuccess = (status == "success")
                        print("卡密验证结果: \(isSuccess ? "成功" : "失败"), 应用ID: \(appId)")
                        
                        // 发送卡密验证结果通知
                        // 明确指定字典类型
                        let userInfo: [String: Any] = ["success": isSuccess, "appId": appId]
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CardVerificationResult"),
                            object: nil,
                            userInfo: userInfo
                        )
                        return true
                    }
                } else if url.host == "disguise" {
                    // 处理伪装模式切换
                    if let queryItems = components?.queryItems,
                       let status = queryItems.first(where: { $0.name == "enabled" })?.value {
                        let isEnabled = (status == "true" || status == "1")
                        print("伪装模式设置: \(isEnabled ? "启用" : "禁用")")
                        
                        // 发送伪装模式变更通知
                        let userInfo = ["enabled": isEnabled]
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DisguiseModeChanged"),
                            object: nil,
                            userInfo: userInfo
                        )
                        
                        // 保存伪装模式设置
                        UserDefaults.standard.setValue(isEnabled, forKey: "disguise_mode_enabled")
                        UserDefaults.standard.synchronize()
                        
                        return true
                    }
                }
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
            
            // 检查是否为伪装模式控制链接
            if url.path.contains("/disguise/") {
                let components = url.pathComponents
                if let index = components.firstIndex(of: "disguise"), index + 1 < components.count {
                    let status = components[index + 1]
                    let isEnabled = (status == "enable" || status == "on")
                    print("从Universal Link设置伪装模式: \(isEnabled ? "启用" : "禁用")")
                    
                    // 发送伪装模式变更通知
                    let userInfo = ["enabled": isEnabled]
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DisguiseModeChanged"),
                        object: nil,
                        userInfo: userInfo
                    )
                    
                    // 保存伪装模式设置
                    UserDefaults.standard.setValue(isEnabled, forKey: "disguise_mode_enabled")
                    UserDefaults.standard.synchronize()
                    
                    return true
                }
            }
        }
        return false
    }
}
