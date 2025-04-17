import Foundation

/// 简单的调试日志工具类
class DebugLogger {
    static let shared = DebugLogger()
    
    private var logFile: URL?
    private var fileHandle: FileHandle?
    
    private init() {
        // 在初始化时设置日志文件
        setupLogFile()
    }
    
    private func setupLogFile() {
        // 不执行任何操作，避免创建日志文件
    }
    
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // 空实现，不执行任何日志记录
    }
    
    func logToFile(_ message: String) {
        // 空实现，不执行任何文件日志记录
    }
}

func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    // 空实现，不执行任何日志记录
}

/// 安全的打印函数，在提交AppStore时不会执行任何操作
func securePrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    // 空实现 - 构建时会将所有print替换为此函数
    #if DEBUG
        // 仅在Debug模式下可选择性输出
        // Swift.print(items, separator: separator, terminator: terminator)
    #endif
}

/// 简单的调试日志工具类
class Debug {
    static let shared = Debug()
    
    // 是否启用日志记录
    private let isEnabled = true
    
    // 日志文件URL
    private var logFileURL: URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent("app_debug.log")
    }
    
    private init() {
        // 清理旧的日志文件，或创建新文件
        if let url = logFileURL {
            // 如果文件大于5MB，清空它
            let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
            if let size = fileSize, size.intValue > 5 * 1024 * 1024 {
                try? "Debug Log - Started \(Date())\n".write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    /// 记录调试信息
    /// - Parameter message: 调试消息内容
    func log(message: String) {
        guard isEnabled else { return }
        
        // 添加时间戳
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // 打印到控制台
        print("DEBUG: \(logMessage)")
        
        // 保存到文件
        saveToFile(logMessage)
    }
    
    /// 记录错误信息
    /// - Parameters:
    ///   - error: 错误对象
    ///   - function: 函数名
    func logError(_ error: Error, function: String = #function) {
        log(message: "ERROR in \(function): \(error.localizedDescription)")
    }
    
    // 将日志保存到文件
    private func saveToFile(_ message: String) {
        guard let url = logFileURL else { return }
        
        do {
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: url.path) {
                // 追加内容
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    if let data = message.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }
            } else {
                // 创建新文件
                try message.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            print("无法写入日志文件: \(error.localizedDescription)")
        }
    }
} 