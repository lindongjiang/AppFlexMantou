import Foundation
import UIKit

func handleIPAFile(destinationURL: URL, uuid: String, dl: AppDownload) throws {
    if !FileManager.default.fileExists(atPath: destinationURL.path) {
        throw NSError(domain: "IPAHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "IPA文件不存在"])
    }
    
    
    let userDefaults = UserDefaults.standard
    
    userDefaults.set(uuid, forKey: "lastDownloadedAppUUID")
    
    let currentTime = Date().timeIntervalSince1970
    userDefaults.set(currentTime, forKey: "appDownloadTime_\(uuid)")
    
    userDefaults.set("示例应用", forKey: "appName_\(uuid)")
    userDefaults.set("com.example.app", forKey: "appBundleID_\(uuid)")
    userDefaults.set("1.0", forKey: "appVersion_\(uuid)")
    
    userDefaults.synchronize()
} 
