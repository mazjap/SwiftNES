import Foundation

extension NES.CPU {
    struct Registers {
        /// Program Counter (PC) - 16-bit register that holds the memory address of the next
        /// instruction to be executed.
        var programCounter: UInt16
        
        /// Accumulator (A) - 8-bit register used for arithmetic and logic operations. Primary
        /// register for ALU operations, data transfer, and memory access.
        var accumulator: UInt8
        
        /// Index Register X (X) - 8-bit register primarily used for:
        /// - Indexing memory addresses
        /// - Counter in loops
        /// - Offset calculations
        var indexX: UInt8
        
        /// Index Register Y (Y) - 8-bit register primarily used for:
        /// - Indexing memory addresses
        /// - Counter in loops
        /// - Offset calculations
        var indexY: UInt8
        
        /// Stack Pointer (SP) - 8-bit register that points to the next free location on the stack.
        /// Stack is located in page 1 ($0100-$01FF) and grows downward.
        var stackPointer: UInt8
        
        /// Status Register (P) - 8-bit register containing processor status flags. Controls
        /// program flow and reflects the results of CPU operations.
        var status: Status
        
        /// Creates a new Registers instance with the initial state of the NES CPU registers.
        ///
        /// - Parameters:
        ///   - programCounter: Program Counter (PC) initial value. Defaults to 0xFFFC,
        ///     which points to the reset vector location in memory where the CPU looks for the
        ///     program entry point.
        ///   - accumulator: Accumulator (A) initial value. Defaults to 0, the standard
        ///     power-up state.
        ///   - indexX: Index Register X initial value. Defaults to 0, the standard power-up state.
        ///   - indexY: Index Register Y initial value. Defaults to 0, the standard power-up state.
        ///   - stackPointer: Stack Pointer (SP) initial value. Defaults to 0xFD, which is the
        ///     standard power-up state, leaving 3 bytes of headroom at the top of the stack.
        ///   - processorStatus: Status Register (P) initial flags. Defaults to .zero (clear
        ///     flags), though some bits may be set depending on the power-up sequence.
        init(
            programCounter: UInt16 = 0xFFFC,
            accumulator: UInt8 = 0,
            indexX: UInt8 = 0,
            indexY: UInt8 = 0,
            stackPointer: UInt8 = 0xFD,
            processorStatus: Status = .empty
        ) {
            self.programCounter = programCounter
            self.accumulator = accumulator
            self.indexX = indexX
            self.indexY = indexY
            self.stackPointer = stackPointer
            self.status = processorStatus
        }
    }
}

extension NES.CPU.Registers {
    /// Creates a new Registers instance with the initial state of the NES CPU registers.
    ///
    /// - Parameters:
    ///   - programCounter: Program Counter (PC) initial value. Defaults to 0xFFFC,
    ///     which points to the reset vector location in memory where the CPU looks for the
    ///     program entry point.
    ///   - accumulator: Accumulator (A) initial value. Defaults to 0, the standard
    ///     power-up state.
    ///   - indexX: Index Register X initial value. Defaults to 0, the standard power-up state.
    ///   - indexY: Index Register Y initial value. Defaults to 0, the standard power-up state.
    ///   - stackPointer: Stack Pointer (SP) initial value. Defaults to 0xFD, which is the
    ///     standard power-up state, leaving 3 bytes of headroom at the top of the stack.
    ///   - processorStatus: Status Register (P) initial flags. Defaults to 0 (clear
    ///     flags), though some bits may be set depending on the power-up sequence.
    @_disfavoredOverload
    init(
        programCounter: UInt16 = 0xFFFC,
        accumulator: UInt8 = 0,
        indexX: UInt8 = 0,
        indexY: UInt8 = 0,
        stackPointer: UInt8 = 0xFD,
        processorStatus: UInt8 = 0
    ) {
        self.init(
            programCounter: programCounter,
            accumulator: accumulator,
            indexX: indexX,
            indexY: indexY,
            stackPointer: stackPointer,
            processorStatus: Status(
                rawValue: processorStatus
            )
        )
    }
}

extension NES.CPU {
    /// Increment the program counter by the amount provided. 1 will be used if no value is provided
    func incrementPc(count: UInt16 = 1) {
        registers.programCounter &+= count
    }
    
    /// Updates the processor status register's zero and negative flags based on the provided value.
    /// If no value is provided, the accumulator's value is used.
    /// - Parameter optionalValue: The value to check for zero and negative flags. If nil, uses accumulator.
    /// - Note: The zero flag is set when the value is 0, and the negative flag is set when bit 7 is set.
    func updateZeroNegativeFlags(for optionalValue: UInt8? = nil) {
        let value = optionalValue ?? registers.accumulator
        
        // Set zero flag based on whether value is 0b00000000 (0)
        registers.status.setFlag(.zero, to: value == 0)
        // Set negative flag based on the most significant bit 0b10000000 (0x80)
        registers.status.setFlag(.negative, to: (Registers.Status.negative.rawValue & value != 0))
    }
}
