extension NES.CPU.Registers {
    public struct Status: OptionSet, Sendable {
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// Checks if specified flag(s) are set in the status register.
        /// - Parameter flag: The flag or flags to check.
        /// - Returns: `true` if all flags specified by `flag` are set, otherwise `false`.
        public func readFlag(_ flag: Status) -> Bool {
            contains(flag)
        }

        /// Sets or clears the specified flag in the status register.
        /// - Parameters:
        ///   - flag: The flag(s) to set or clear.
        ///   - value: If `true`, sets the flag; if `false`, clears the flag.
        public mutating func setFlag(_ flag: Status, to value: Bool) {
            if value {
                insert(flag)
            } else {
                remove(flag)
            }
        }
        
        public static let carry = Status(rawValue: 1)
        public static let zero = Status(rawValue: 1 << 1)
        public static let interrupt = Status(rawValue: 1 << 2)
        public static let decimal = Status(rawValue: 1 << 3)
        public static let `break` = Status(rawValue: 1 << 4)
        public static let overflow = Status(rawValue: 1 << 6)
        public static let negative = Status(rawValue: 1 << 7)
    }
}

extension NES.CPU.Registers.Status: CustomStringConvertible {
    public var description: String {
        var binaryString = String(rawValue, radix: 2)
        
        if binaryString.count < 8 {
            binaryString = String(repeating: "0", count: 8 - binaryString.count) + binaryString
        }
        
        return "\nNO_BDIZC\n\(binaryString)"
    }
    
    public static let empty = Self([])
}
