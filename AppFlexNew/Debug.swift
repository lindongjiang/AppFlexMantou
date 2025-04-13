import Foundation

class Debug {
    static let shared = Debug()
    
    private init() {}
    
    func log(message: String) {
        #if DEBUG
        print("[Debug] \(message)")
        #endif
    }
} 