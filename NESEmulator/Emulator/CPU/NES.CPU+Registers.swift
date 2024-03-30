import Foundation

extension NES.CPU {
    struct Registers {
        var programCounter: UInt16
        
        var accumulator: UInt8
        var indexX: UInt8
        var indexY: UInt8
        var stackPointer: UInt8
        
        var processorStatus: UInt8
        
        init(programCounter: UInt16 = 0x8000, accumulator: UInt8 = 0, indexX: UInt8 = 0, indexY: UInt8 = 0, stackPointer: UInt8 = 0xFD, processorStatus: UInt8 = 0) {
            self.programCounter = programCounter
            self.accumulator = accumulator
            self.indexX = indexX
            self.indexY = indexY
            self.stackPointer = stackPointer
            self.processorStatus = processorStatus
        }
        
        // Processor Status Flags
        
        var carry: Bool {
            get {
                (processorStatus & Self.carryFlag) != 0
            }
            set {
                if newValue {
                    processorStatus |= Self.carryFlag
                } else {
                    processorStatus &= ~Self.carryFlag
                }
            }
        }
        
        var zero: Bool {
            get {
                (processorStatus & Self.zeroFlag) != 0
            }
            set {
                if newValue {
                    processorStatus |= Self.zeroFlag
                } else {
                    processorStatus &= ~Self.zeroFlag
                }
            }
        }
        
        var interruptDisabled: Bool {
            get {
                (processorStatus & Self.interruptFlag) != 0
            }
            set {
                if newValue {
                    processorStatus |= Self.interruptFlag
                } else {
                    processorStatus &= ~Self.interruptFlag
                }
            }
        }
        
        var decimal: Bool {
            get {
                (processorStatus & Self.decimalFlag) != 0
            }
            set {
                if newValue {
                    processorStatus |= Self.decimalFlag
                } else {
                    processorStatus &= ~Self.decimalFlag
                }
            }
        }
        
//        var bFlag: {}
        
        var overflow: Bool {
            get {
                (processorStatus & Self.overflowFlag) != 0
            }
            set {
                if newValue {
                    processorStatus |= Self.overflowFlag
                } else {
                    processorStatus &= ~Self.overflowFlag
                }
            }
        }
        
        var negative: Bool {
            get {
                (processorStatus & Self.negativeFlag) != 0
            }
            set {
                if newValue {
                    processorStatus |= Self.negativeFlag
                } else {
                    processorStatus &= ~Self.negativeFlag
                }
            }
        }
        
        static let carryFlag: UInt8 = 1
        static let zeroFlag: UInt8 = (1 << 1)
        static let interruptFlag: UInt8 = (1 << 2)
        static let decimalFlag: UInt8 = (1 << 3)
        static let overflowFlag: UInt8 = (1 << 6)
        static let negativeFlag: UInt8 = (1 << 7)
    }
}

extension NES.CPU {
    /// Increment the program counter by the amount provided. 1 will be used if no value is provided
    func incrementPc(count: UInt16 = 1) {
        registers.programCounter &+= count
    }
    
    /// Update the Zero and Negative flags using the provided value. Accumulator will be used if no value is provided
    func updateZeroNegativeFlags(for optionalValue: UInt8? = nil) {
        let value = optionalValue ?? registers.accumulator
        
        // Set zero flag based on whether value is 0b00000000 (0) or 0b10000000 (-0)
        if value == 0 || value == Registers.negativeFlag {
            setZeroFlag()
        } else {
            clearZeroFlag()
        }
        
        if (value & Registers.negativeFlag) != 0 {
            setNegativeFlag()
        } else {
            clearNegativeFlag()
        }
    }
    
    func setZeroFlag() {
        registers.zero = true
    }
    
    func clearZeroFlag() {
        registers.zero = false
    }
    
    func setNegativeFlag() {
        registers.negative = true
    }
    
    func clearNegativeFlag() {
        registers.negative = false
    }
    
    func setCarryFlag() {
        registers.carry = true
    }
    
    func clearCarryFlag() {
        registers.carry = false
    }
    
    func setOverflowFlag() {
        registers.overflow = true
    }
    
    func clearOverflowFlag() {
        registers.overflow = false
    }
}
