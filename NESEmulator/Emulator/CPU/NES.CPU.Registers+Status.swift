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

extension NES.CPU.Registers.Status {
    struct Flag: OptionSet {
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
