import Foundation
import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    struct DownloadedApp {
        let uuid: String
        let name: String
        let bundleidentifier: String?
        let version: String
        let iconPath: String?
    }
    
    private init() {
    }
    
    func getDatedDownloadedApps() -> [DownloadedApp] {
        return [
            DownloadedApp(
                uuid: "mock-uuid-1", 
                name: "模拟应用1", 
                bundleidentifier: "com.example.app1", 
                version: "1.0", 
                iconPath: nil
            ),
            DownloadedApp(
                uuid: "mock-uuid-2", 
                name: "模拟应用2", 
                bundleidentifier: "com.example.app2", 
                version: "2.0", 
                iconPath: nil
            )
        ]
    }
    
    func getSourceData(urlString: String, completion: @escaping (Error?) -> Void) {
        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: 0.5)
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
} 
