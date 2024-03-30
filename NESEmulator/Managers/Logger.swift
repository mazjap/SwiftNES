import Foundation
import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.mazjap.NESEmulator"
    
    static let emu = Logger(subsystem: subsystem, category: "emulatorCPUOperations")
}

let emuLogger = Logger.emu
