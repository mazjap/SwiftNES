extension NES.CPU.Registers {
    struct Status: OptionSet {
        var rawValue: UInt8
        
        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// Checks if specified flag(s) are set in the status register.
        /// - Parameter flag: The flag or flags to check.
        /// - Returns: `true` if all flags specified by `flag` are set, otherwise `false`.
        func readFlag(_ flag: Status) -> Bool {
            contains(flag)
        }

        /// Sets or clears the specified flag in the status register.
        /// - Parameters:
        ///   - flag: The flag(s) to set or clear.
        ///   - value: If `true`, sets the flag; if `false`, clears the flag.
        mutating func setFlag(_ flag: Status, to value: Bool) {
            if value {
                insert(flag)
            } else {
                remove(flag)
            }
        }
        
        static let carry = Status(rawValue: 1)
        static let zero = Status(rawValue: 1 << 1)
        static let interrupt = Status(rawValue: 1 << 2)
        static let decimal = Status(rawValue: 1 << 3)
        static let `break` = Status(rawValue: 1 << 4)
        static let overflow = Status(rawValue: 1 << 6)
        static let negative = Status(rawValue: 1 << 7)
    }
}

extension NES.CPU.Registers.Status: CustomStringConvertible {
    var description: String {
        var binaryString = String(rawValue, radix: 2)
        
        if binaryString.count < 8 {
            binaryString = String(repeating: "0", count: 8 - binaryString.count) + binaryString
        }
        
        return "\nNO_BDIZC\n\(binaryString)"
    }
    
    static let empty = Self([])
}
