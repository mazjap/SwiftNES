import Foundation
import OSLog

extension Logger {
    static let emu = {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.mazjap.SwiftNESTest"
        let category = "emulatorCPUOperations"
        
        return Logger(subsystem: subsystem, category: category)
    }()
}

let emuLogger = Logger.emu
