import Foundation

/// 简单的调试日志工具类
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

/// 安全的打印函数，在提交AppStore时不会执行任何操作
func securePrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    #endif
}

/// 简单的调试日志工具类
class Debug {
    static let shared = Debug()
    
    private let isEnabled = true
    
    private var logFileURL: URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent("app_debug.log")
    }
    
    private init() {
    }
    
    /// 记录调试信息
    func log(message: String) {
        guard isEnabled else { return }
        
        saveToFile(message)
    }
    
    /// 记录错误信息
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