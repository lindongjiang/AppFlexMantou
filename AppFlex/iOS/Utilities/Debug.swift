import Foundation

class DebugLogger {
    static let shared = DebugLogger()
    
    private var logFile: URL?
    private var fileHandle: FileHandle?
    
    private init() {
    }
    
    private func setupLogFile() {
    }
    
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    }
    
    func logToFile(_ message: String) {
    }
}

func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
}

func securePrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    #endif
}

class Debug {
    static let shared = Debug()
    
    private let isEnabled = true
    
    private var logFileURL: URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent("app_debug.log")
    }
    
    private init() {
    }
    
    func log(message: String) {
        guard isEnabled else { return }
        
        saveToFile(message)
    }
    
    func logError(_ error: Error, function: String = #function) {
        log(message: "ERROR in \(function): \(error.localizedDescription)")
    }
    
    private func saveToFile(_ message: String) {
        guard let url = logFileURL else { return }
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    if let data = message.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }
            } else {
                try message.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
        }
    }
} 
