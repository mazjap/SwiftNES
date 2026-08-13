import Foundation
import OSLog

protocol Loggerable: Sendable {
    func error(_ message: String)
    func debug(_ message: String)
    func warning(_ message: String)
    func info(_ message: String)
    func notice(_ message: String)
}

extension Logger: Loggerable {
    static let emu = {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.mazjap.SwiftNESTest"
        let category = "emulatorCPUOperations"
        
        return Logger(subsystem: subsystem, category: category)
    }()
    
    @_disfavoredOverload
    func error(_ message: String) { self.error("\(message)") }
    @_disfavoredOverload
    func debug(_ message: String) { self.debug("\(message)") }
    @_disfavoredOverload
    func warning(_ message: String) { self.warning("\(message)") }
    @_disfavoredOverload
    func info(_ message: String) { self.info("\(message)") }
    @_disfavoredOverload
    func notice(_ message: String) { self.notice("\(message)") }
}

struct NopLogger: Loggerable {
    func error(_ message: String) {}
    func debug(_ message: String) {}
    func warning(_ message: String) {}
    func info(_ message: String) {}
    func notice(_ message: String) {}
}

#if DEBUG
let emuLogger: Loggerable = Logger.emu
#else
let emuLogger: Loggerable = NopLogger()
#endif
