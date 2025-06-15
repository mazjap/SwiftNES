#if DEBUG
import OSLog

extension Logger {
    static let emu = {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.mazjap.SwiftNESTest"
        let category = "emulatorCPUOperations"
        
        return Logger(subsystem: subsystem, category: category)
    }()
}

let emuLogger = Logger.emu
#else
final class Logger: Sendable {
    func error(_ message: String) {}
    func notice(_ message: String) {}
    func warning(_ message: String) {}
    func debug(_ message: String) {}
}

let emuLogger = Logger()
#endif
