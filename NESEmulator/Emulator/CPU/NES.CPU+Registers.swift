import Foundation

extension NES.CPU {
    struct Registers {
        var programCounter: UInt16
        
        var accumulator: UInt8
        var indexX: UInt8
        var indexY: UInt8
        var stackPointer: UInt8
        
        var status: Status
        
        init(
            programCounter: UInt16 = 0x8000,
            accumulator: UInt8 = 0,
            indexX: UInt8 = 0,
            indexY: UInt8 = 0,
            stackPointer: UInt8 = 0xFD,
            processorStatus: UInt8 = 0
        ) {
            self.programCounter = programCounter
            self.accumulator = accumulator
            self.indexX = indexX
            self.indexY = indexY
            self.stackPointer = stackPointer
            self.status = Status(status: processorStatus)
        }
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
        registers.status.setFlag(.zero, to: value == 0 || value == Registers.Status.Flag.negative.rawValue)
        // Set negative flag based on the most significant bit
        registers.status.setFlag(.negative, to: (Registers.Status.Flag.negative.rawValue) != 0)
    }
}
