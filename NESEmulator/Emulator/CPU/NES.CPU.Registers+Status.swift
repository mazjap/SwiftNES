extension NES.CPU.Registers {
    struct Status {
        var rawValue: UInt8
        
        init(status: UInt8) {
            self.rawValue = status
        }
        
        /// Checks if specified flag(s) are set in the status register.
        /// - Parameter flag: The flag or flags to check.
        /// - Returns: `true` if all flags specified by `flag` are set, otherwise `false`.
        func readFlag(_ flag: Flag) -> Bool {
            (rawValue & flag.rawValue) == flag.rawValue
        }

        /// Sets or clears the specified flag in the status register.
        /// - Parameters:
        ///   - flag: The flag to set or clear.
        ///   - value: If `true`, sets the flag; if `false`, clears the flag.
        mutating func setFlag(_ flag: Flag, to value: Bool) {
            if value {
                rawValue |= flag.rawValue
            } else {
                rawValue &= ~flag.rawValue
            }
        }
    }
}

extension NES.CPU.Registers.Status: CustomStringConvertible {
    init(setFlags: Set<Flag>) {
        self.init(status: 0)
        for flag in setFlags {
            self.setFlag(flag, to: true)
        }
    }
    
    var description: String {
        var binaryString = String(rawValue, radix: 2)
        
        if binaryString.count < 8 {
            binaryString = String(repeating: "0", count: 8 - binaryString.count) + binaryString
        }
        
        return "\nNO_BDIZC\n\(binaryString)"
    }
    
    static let zero = Self(status: 0)
}

extension NES.CPU.Registers.Status {
    struct Flag: OptionSet, Hashable {
        var rawValue: UInt8
        
        static let carry = Flag(rawValue: 1)
        static let zero = Flag(rawValue: 1 << 1)
        static let interrupt = Flag(rawValue: 1 << 2)
        static let decimal = Flag(rawValue: 1 << 3)
        static let `break` = Flag(rawValue: 1 << 4)
        static let overflow = Flag(rawValue: 1 << 6)
        static let negative = Flag(rawValue: 1 << 7)
    }
}
