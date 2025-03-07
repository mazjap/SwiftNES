extension NES.CPU {
    /// Break:
    /// Pushes the program counter and processor status to the stack.
    /// Loads the interrupt vector from 0xFFFE/F into the program counter.
    /// Sets the break flag status to 1 (only on the status pushed to the stack).
    func brk() {
        emuLogger.debug("brk")
        
        // PC + 2 is pushed (BRK is treated as a 2-byte instruction even though second byte is ignored)
        registers.programCounter &+= 1
        
        // Push PC and status (with B flag set) to stack
        push(UInt8((registers.programCounter >> 8) & 0xFF))
        push(UInt8(registers.programCounter & 0xFF))
        push(registers.status.rawValue | Registers.Status.break.rawValue) // Status with B flag set (bit 5 should be too, but it shouldn't matter as it's ignored everywhere)
        
        // Set interrupt disable flag
        registers.status.setFlag(.interrupt, to: true)
        
        // Load interrupt vector
        let lowByte = UInt16(memoryManager.read(from: 0xFFFE))
        let highByte = UInt16(memoryManager.read(from: 0xFFFF))
        registers.programCounter = lowByte | (highByte << 8)
    }
    
    /// Logical Inclusive OR:
    /// Performs a bitwise OR operation, bit by bit, on the accumulator with the value fetched using the specified addressing mode.
    /// - Parameter value: The value fetched using the specified addressing mode to be ORed with the accumulator
    func ora(value: UInt8) {
        emuLogger.debug("ora")
        registers.accumulator |= value
        updateZeroNegativeFlags()
    }
    
    /// Stop / Jam / Kill:
    /// An illegal opcode that indefinitely traps the CPU in an undefined state, typically referred to as T1 phase, with 0xFF on the data bus.
    /// This operation is not used by any NES program and is implemented here as a `fatalError` to indicate an unreachable state.
    func stp() {
        emuLogger.debug("stp")
        /*big*/ if true {
            fatalError("Illegal opcode 'stp/kil/jam' encountered. This is an unreachable state and indicates a severe error in the emulator.")
        }
    }
    
    /// Shift Left Logical OR:
    /// Shifts all bits in the value one place to the left and then ORs the accumulator with the result.
    /// - Parameter value: The value to perform the SLO operation on
    func slo(value: inout UInt8) {
        emuLogger.debug("slo")
        
        asl(value: &value)
        ora(value: value)
    }
    
    /// No Operation:
    func nop() {
        emuLogger.debug("nop")
        
        // TODO: - Urgent: Do nothing
    }
    
    /// Arithmetic Shift Left:
    /// Shifts the value left 1 bit and updates carry, zero, and negative flags.
    func asl(value: inout UInt8) {
        emuLogger.debug("asl")
        
        // Check for carry before performing shift
        registers.status.setFlag(.carry, to: value & .mostSignificantBit != 0)
        
        value <<= 1
        
        updateZeroNegativeFlags(for: value)
    }
    
    // TODO: - Rejoin two ASL functions (LSR, ROL, ROR too)
    // For some reason, when passing in the accumulator as the inout parameter of asl,
    // I get a "simultaneous access" fatal error. My (limited) understanding is that
    // because accumulator comes from the Registers struct as well as the status,
    // the Registers struct could possibly be mutated (or read and written to)
    // simultaneously. That shouldn't be possible here, but I couldn't find a
    // satisfying work around. I've come to this compromise, two seperate functions,
    // though I want to find a good solution and rejoin these two functions into one
    
    /// Accumulator Shift Left:
    /// Shifts the accumulator left 1 bit and updates carry, zero, and negative flags.
    func aslA() {
        emuLogger.debug("asl")
        
        // Check for carry before performing shift
        registers.status.setFlag(.carry, to: registers.accumulator & .mostSignificantBit != 0)
        
        registers.accumulator <<= 1
        
        updateZeroNegativeFlags()
    }
    
    /// Push Processor Status:
    /// Pushes the current status register (processor status) onto the stack with the break flag and bit 5 set to 1.
    /// Updates the stack pointer.
    func php() {
        emuLogger.debug("php")
        
        // Bit 5 is overridden in this context
        push(registers.status.rawValue | Registers.Status.break.rawValue)
    }
    
    /// AND with Carry:
    /// Performs a bitwise AND between the accumulator and the specified value, and then sets the carry flag to the same value as bit 7 of the result.
    /// - Parameter value: The value to perform the AND operation with the accumulator.
    func anc(value: UInt8) {
        emuLogger.debug("anc")
        
        and(value: value)
        
        registers.status.setFlag(.carry, to: registers.accumulator & .mostSignificantBit != 0)
    }
    
    /// Branch if Positive:
    /// If the negative flag is clear then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func bpl(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("bpl")
        
        if !registers.status.readFlag(.negative) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Clear Carry Flag:
    func clc() {
        emuLogger.debug("clc")
        
        registers.status.setFlag(.carry, to: false)
    }
    
    /// Jump to Subroutine:
    /// Pushes the address of the return point on to the stack and then sets the program counter to the target memory address.
    func jsr(value: UInt16) {
        emuLogger.debug("jsr")
        
        let returnValue = registers.programCounter &- 1
        
        push(UInt8((returnValue >> 8) & 0xFF))
        push(UInt8(returnValue & 0xFF))
        
        registers.programCounter = value
    }
    
    /// And:
    /// Performs a bitwise AND operation between the accumulator and the provided value.
    /// Updates the zero and negative flags.
    func and(value: UInt8) {
        registers.accumulator &= value
        updateZeroNegativeFlags()
        
        emuLogger.debug("and")
    }
    
    /// Rotate Left + And:
    /// An "Illegal" Opcode.
    func rla(value: inout UInt8) {
        rol(value: &value)
        and(value: value)
    }
    
    /// Test Bits in Memory with Accumulator:
    /// Transfer bits 7 and 6 of operand to bit 7 and 6 of SR (N,V).
    /// The zero-flag is set according to the result of the operand AND the accumulator (set, if the result is zero, unset otherwise).
    /// This allows a quick check of a few bits at once without affecting any of the registers, other than the status register (SR).
    func bit(value: UInt8) {
        emuLogger.debug("bit")

        registers.status.setFlag(.negative, to: (value & 0b10000000) != 0)
        registers.status.setFlag(.overflow, to: (value & 0b01000000) != 0)
        registers.status.setFlag(.zero, to: (registers.accumulator & value) == 0)
    }
    
    /// Rotate Left:
    /// Shifts all bits in the value one place to the left.
    /// Carry flag becomes bit 0 while the old bit 7 becomes the new carry flag.
    func rol(value: inout UInt8) {
        emuLogger.debug("rol")
        
        let newCarry = (value & .mostSignificantBit) != 0
        value <<= 1
        value |= registers.status.readFlag(.carry) ? 1 : 0
        registers.status.setFlag(.carry, to: newCarry)
        
        updateZeroNegativeFlags(for: value)
    }
    
    /// Rotate Left:
    /// Shifts all bits in the accumulator one place to the left.
    /// Carry flag becomes bit 0 while the old bit 7 becomes the new carry flag.
    func rolA() {
        emuLogger.debug("rol")
        
        let newCarry = (registers.accumulator & .mostSignificantBit) != 0
        registers.accumulator <<= 1
        registers.accumulator |= registers.status.readFlag(.carry) ? 1 : 0
        registers.status.setFlag(.carry, to: newCarry)
        
        updateZeroNegativeFlags()
    }
    
    /// Pull Processor Status:
    /// Pulls an 8 bit value from the stack and into the processor status register (SR).
    func plp() {
        emuLogger.debug("plp")
        
        registers.status.rawValue = pop() & ~Registers.Status.break.rawValue
    }
    
    /// Branch if Minus (Negative):
    /// If the negative flag is set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func bmi(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("bmi")
        
        if registers.status.readFlag(.negative) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Set Carry Flag:
    func sec() {
        emuLogger.debug("sec")
        
        registers.status.setFlag(.carry, to: true)
    }
    
    /// Return from Interrupt:
    /// Pulls the processor status register and the program counter from the stack.
    func rti() {
        emuLogger.debug("rti")
        
        let status = pop()
        registers.status.rawValue = status & ~Registers.Status.break.rawValue
        
        let lowByte = UInt16(pop())
        let highByte = UInt16(pop()) << 8
        
        registers.programCounter = lowByte | highByte
    }
    
    /// Exclusive-OR (XOR):
    /// An exclusive OR is performed, bit by bit, on the accumulator register using the provided value.
    /// The result is stored back into the accumulator.
    func eor(value: UInt8) {
        emuLogger.debug("eor")
        
        registers.accumulator ^= value
        
        updateZeroNegativeFlags()
    }
    
    /// LSR + EOR:
    /// An "Illegal" Opcode.
    /// Shifts all bits in the value one place to the right, then XORs the result with the accumulator.
    func sre(value: inout UInt8) {
        emuLogger.debug("sre")
        
        lsr(value: &value)
        eor(value: value)
    }
    
    /// Logical Shift Right:
    /// Shifts all bits in the value one place to the right, storing the old bit 0 in the carry flag.
    func lsr(value: inout UInt8) {
        emuLogger.debug("lsr")
        
        let newCarry = (value & 1) != 0
        
        value >>= 1
        
        registers.status.setFlag(.carry, to: newCarry)
        updateZeroNegativeFlags(for: value)
    }
    
    /// Logical Shift Right:
    /// Shifts all accumulator bits in the value one place to the right, storing the old bit 0 in the carry flag.
    func lsrA() {
        emuLogger.debug("lsr")
        
        let newCarry = (registers.accumulator & 1) != 0
        
        registers.accumulator >>= 1
        
        registers.status.setFlag(.carry, to: newCarry)
        updateZeroNegativeFlags()
    }
    
    /// Push Accumulator:
    /// Pushes the contents of the accumulator on to the stack.
    func pha() {
        emuLogger.debug("pha")
        
        push(registers.accumulator)
    }
    
    /// AND + Logical Shift Right:
    /// An "Illegal" Opcode.
    func alr(value: UInt8) {
        emuLogger.debug("alr")
        
        and(value: value)
        
        // Re-implement LSR
        let carry = registers.accumulator & 0x01 // Save the original carry before shifting
        registers.accumulator >>= 1
        registers.status.setFlag(.carry, to: carry != 0)
        
        // Update zero and negative flags
        updateZeroNegativeFlags(for: registers.accumulator)
    }
    
    /// Jump:
    /// The program counter is set to the address specified by the operand.
    func jmp(value: UInt16) {
        emuLogger.debug("jmp")
        
        registers.programCounter = value
    }
    
    /// Branch if Overflow Clear:
    /// If the negative flag is clear then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func bvc(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("bvc")
        
        if !registers.status.readFlag(.overflow) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Clear Interrupt Flag:
    /// Clears the interrupt disable flag in the processor status register, allowing the CPU to respond to interrupts.
    func cli() {
        emuLogger.debug("cli")
        
        registers.status.setFlag(.interrupt, to: false)
    }
    
    /// Return from Subroutine:
    /// Restores the program counter (PC) to the address on the stack, then increments the PC to the address following the original subroutine call.
    func rts() {
        emuLogger.debug("rts")
        
        let low = UInt16(pop())
        let high = UInt16(pop()) << 8
        
        let value = (high | low) &+ 1
        
        registers.programCounter = value
    }
    
    /// Add with Carry:
    /// Adds a given byte to the accumulator along with the carry bit, updating the flags for zero, carry, overflow, and negative results.
    /// - Parameters:
    ///   - value: The byte to add to the accumulator.
    func adc(value: UInt8) {
        emuLogger.debug("adc")
        
        let carry: UInt16 = registers.status.readFlag(.carry) ? 1 : 0
        let sum = UInt16(registers.accumulator) + UInt16(value) + carry
        registers.status.setFlag(.carry, to: sum > 0xFF)
        
        let newAccumulator = UInt8(sum & 0xFF) // Truncate to 8 bits
        registers.status.setFlag(.zero, to: newAccumulator == 0)
        registers.status.setFlag(.negative, to: newAccumulator & .mostSignificantBit != 0)
        registers.status.setFlag(.overflow, to: ((registers.accumulator ^ newAccumulator) & (value ^ newAccumulator) & .mostSignificantBit) != 0)
        
        registers.accumulator = newAccumulator
    }
    
    /// ROR + ADC:
    /// An "Illegal" Opcode.
    func rra(value: inout UInt8) {
        emuLogger.debug("rra")
        
        ror(value: &value)
        adc(value: value)
    }
    
    /// Rotate Right:
    /// Shifts all bits in the value one place to the right.
    /// Carry flag becomes bit 7 while the old bit 0 becomes the new carry flag.
    func ror(value: inout UInt8) {
        emuLogger.debug("ror")
        
        let newCarry = (value & 0x1) != 0
        value >>= 1
        value |= registers.status.readFlag(.carry) ? .mostSignificantBit : 0
        registers.status.setFlag(.carry, to: newCarry)
        
        updateZeroNegativeFlags(for: value)
    }
    
    /// Rotate Right:
    /// Shifts all bits in the accumulator one place to the right.
    /// Carry flag becomes bit 7 while the old bit 0 becomes the new carry flag.
    func rorA() {
        emuLogger.debug("ror")
        
        let newCarry = (registers.accumulator & 0x1) != 0
        registers.accumulator >>= 1
        registers.accumulator |= registers.status.readFlag(.carry) ? .mostSignificantBit : 0
        registers.status.setFlag(.carry, to: newCarry)
        
        updateZeroNegativeFlags()
    }
    
    /// Pull Accumulator:
    /// Pulls an 8 bit value from the stack and into the accumulator.
    func pla() {
        emuLogger.debug("pla")
        
        let value = pop()
        
        registers.accumulator = value
        updateZeroNegativeFlags(for: value)
    }
    
    /// AND + ROR:
    /// An "Illegal" Opcode.
    func arr(value: UInt8) {
        emuLogger.debug("arr")
        
        // Perform AND operation
        let result = registers.accumulator & value
        
        // Rotate right by one bit
        let oldCarry: UInt8 = registers.status.readFlag(.carry) ? 1 : 0
        let rotatedResult = (result >> 1) | (oldCarry << 7)
        
        // Carry flag should be set based on bit 6 of the result which is a weird quirk
        // (Using bit 7 before rotation, instead of bit 6 after rotation. Same result)
        registers.status.setFlag(.carry, to: (result & 0x40) != 0)
        
        // Update zero and negative flags normally
        updateZeroNegativeFlags(for: rotatedResult)
        
        // Set overflow flag based on XOR of bits 5 and 6 of the AND result
        // Another quirk of ARR
        let vFlag = ((result & 0x40) ^ (result & 0x20)) != 0
        registers.status.setFlag(.overflow, to: vFlag)
        
        // Update accumulator with the result
        registers.accumulator = rotatedResult
    }
    
    /// Branch if Overflow Set:
    /// If the overflow flag is set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func bvs(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("bvs")
        
        if registers.status.readFlag(.overflow) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Set Interrupt Disable:
    func sei() {
        emuLogger.debug("sei")
        
        registers.status.setFlag(.interrupt, to: true)
    }
    
    /// Store Accumulator:
    /// Stores the value of the accumulator at the specified memory address.
    /// - Parameters:
    ///   - value: The memory address where the register's value will be stored.
    func sta(value address: UInt16) {
        emuLogger.debug("sta")
        
        memoryManager.write(registers.accumulator, to: address)
    }
    
    /// AND Accumulator + indexX, then store result at the specified memory address:
    /// Illegal Opcode.
    func sax(value address: UInt16) {
        emuLogger.debug("sax")
        
        let result = registers.accumulator & registers.indexX
        memoryManager.write(result, to: address)
    }
    
    /// Store Y Register:
    /// Stores the value of the y register at the specified memory address.
    /// - Parameters:
    ///   - value: The memory address where the register's value will be stored.
    func sty(value address: UInt16) {
        emuLogger.debug("sty")
        
        memoryManager.write(registers.indexY, to: address)
    }
    
    /// Store X Register:
    /// Stores the value of the x register at the specified memory address.
    /// - Parameters:
    ///   - value: The memory address where the register's value will be stored.
    func stx(value address: UInt16) {
        emuLogger.debug("stx")
        
        memoryManager.write(registers.indexX, to: address)
    }
    
    /// Decrement Y Register:
    /// Updates the zero and negative flags based on the result.
    func dey() {
        emuLogger.debug("dey")
        
        registers.indexY &-= 1
        updateZeroNegativeFlags(for: registers.indexY)
    }
    
    /// Transfer X to Accumulator:
    /// Updates the zero and negative flags based on the result.
    func txa() { // x gon give it to ya
        emuLogger.debug("txa")
        
        registers.accumulator = registers.indexX
        updateZeroNegativeFlags()
    }
    
    /// * AND X + AND oper:
    /// An "Illegal" Opcode.
    /// Unstable - do not use.
    /// From 'Now Go Bang' - "The value of this constant depends on temperature, the chip series, and maybe other factors" 
    func xaa() {
        emuLogger.debug("xaa")
        
        fatalError("XAA is not implemented")
    }
    
    /// Branch if Carry Clear:
    /// If the carry flag is not set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func bcc(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("bcc")
        
        if !registers.status.readFlag(.carry) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Stores A & X AND high byte of addr + 1 at addr
    /// "Illegal" Opcode.
    /// Unstable - do not use.
    func ahx() {
        emuLogger.debug("ahx")
        
        fatalError("AHX not implemented")
    }
    
    /// Transfer Y to Accumulator:
    /// Updates the zero and negative flags.
    func tya() {
        emuLogger.debug("tya")
        
        registers.accumulator = registers.indexY
        updateZeroNegativeFlags()
    }
    
    /// Transfer X to Stack Pointer:
    func txs() {
        emuLogger.debug("txs")
        
        registers.stackPointer = registers.indexX
    }
    
    /// Put A & X in SP and store A & X & high byte of addr at addr
    /// "Illegal" Opcode.
    /// Unstable - do not use.
    func tas() {
        emuLogger.debug("tas")
        
        fatalError("TAS not implemented")
    }
    
    /// Stores Y AND (high-byte of addr. + 1) at addr.
    /// "Illegal" Opcode.
    /// Unstable - do not use.
    func shy() {
        emuLogger.debug("shy")
        
        fatalError("SHY not implemented")
    }
    
    /// Stores X AND (high-byte of addr. + 1) at addr.
    /// "Illegal" Opcode.
    /// Unstable - do not use.
    func shx() {
        emuLogger.debug("shx")
        
        fatalError("SHX not implemented")
    }
    
    /// Load Y Register:
    /// Sets the zero and negative flags.
    func ldy(value: UInt8) {
        emuLogger.debug("ldy")
        
        registers.indexY = value
        updateZeroNegativeFlags(for: value)
    }
    
    /// Load Accumulator Register:
    /// Sets the zero and negative flags.
    func lda(value: UInt8) {
        emuLogger.debug("lda")
        
        registers.accumulator = value
        
        updateZeroNegativeFlags()
    }
    
    /// Load X Register:
    /// Sets the zero and negative flags.
    func ldx(value: UInt8) {
        emuLogger.debug("ldx")
        
        registers.indexX = value
        updateZeroNegativeFlags(for: value)
    }
    
    /// LDA oper + LDX oper:
    /// "Illegal" Opcode
    /// Sets the zero and negative flags.
    func lax(value: UInt8) {
        emuLogger.debug("lax")
        
        registers.accumulator = value
        registers.indexX = value
        
        updateZeroNegativeFlags(for: value)
    }
    
    /// Transfer Accumulator to Y:
    /// Sets zero and negative flags.
    func tay() {
        emuLogger.debug("tay")
        
        registers.indexY = registers.accumulator
        updateZeroNegativeFlags(for: registers.indexY)
    }
    
    /// Transfer Accumulator to X:
    /// Sets zero and negative flags.
    func tax() {
        emuLogger.debug("tax")
        
        registers.indexX = registers.accumulator
        updateZeroNegativeFlags(for: registers.indexX)
    }
    
    /// Branch if Carry Set:
    /// If the carry flag is set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func bcs(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("bcs")
        
        if registers.status.readFlag(.carry) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Clear Overflow Flag:
    func clv() {
        emuLogger.debug("clv")
        
        registers.status.setFlag(.overflow, to: false)
    }
    
    /// Transfer Stack Pointer to X:
    /// Sets the zero and negative flags.
    func tsx() {
        emuLogger.debug("tsx")
        
        registers.indexX = registers.stackPointer
        
        updateZeroNegativeFlags(for: registers.indexX)
    }
    
    /// LDA/TSX oper:
    /// "Illegal" Opcode.
    /// ANDs provided value with the stack pointer, and then updates the accumulator and index X register with the result.
    func las(value: UInt8) {
        emuLogger.debug("las")
        
        let result = registers.stackPointer & value
        
        registers.stackPointer = result
        registers.indexX = result
        registers.accumulator = result
        
        updateZeroNegativeFlags()
    }
    
    /// Compare Y Register:
    /// Compares the contents of the Y register with a specified value and sets the zero, carry, and negative flags based on the result.
    /// - Parameters:
    ///   - value: The value to compare with the Y register.
    func cpy(value: UInt8) {
        emuLogger.debug("cpy")
        
        let result = Int(registers.indexY) - Int(value)
        
        registers.status.setFlag(.carry, to: registers.indexY >= value)
        registers.status.setFlag(.zero, to: registers.indexY == value)
        registers.status.setFlag(.negative, to: (result & 0x80) != 0)
    }
    
    /// Compare Accumulator:
    /// Compares the contents of the Accumulator register with a specified value and sets the zero, carry, and negative flags based on the result.
    /// - Parameters:
    ///   - value: The value to compare with Accumulator.
    func cmp(value: UInt8) {
        emuLogger.debug("cmp")
        
        let result = registers.accumulator &- value
        
        registers.status.setFlag(.carry, to: registers.accumulator >= value)
        registers.status.setFlag(.zero, to: registers.accumulator == value)
        registers.status.setFlag(.negative, to: (result & .mostSignificantBit) != 0)
    }
    
    /// DEC + CPM
    /// "Illegal" Opcode.
    /// Decrements the given value by one and compares the result with the accumulator.
    /// Updates the carry, zero, and negative flags based on the comparison.
    func dcp(value: inout UInt8) {
        emuLogger.debug("dcp")
        
        value &-= 1
        
        let result = registers.accumulator - value
        
        registers.status.setFlag(.carry, to: registers.accumulator >= value)
        registers.status.setFlag(.zero, to: registers.accumulator == value)
        registers.status.setFlag(.negative, to: (result & .mostSignificantBit) != 0)
    }
    
    /// Decrement Memory:
    /// Subtracts one from the value at the specified memory location.
    /// - Parameter value: Memory location to decrement, passed by reference
    /// - Note: Updates zero and negative flags based on the result.
    ///   DEC affects flags:
    ///     - Zero (Z): Set if result is zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of result is set, cleared otherwise
    func dec(value: inout UInt8) {
        emuLogger.debug("dec")
        
        value &-= 1
        
        updateZeroNegativeFlags(for: value)
    }

    /// Increment Y Register:
    /// Adds one to the Y index register.
    /// - Note: Updates zero and negative flags based on the result.
    ///   INY affects flags:
    ///     - Zero (Z): Set if Y becomes zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of Y is set, cleared otherwise
    func iny() {
        emuLogger.debug("iny")
        
        registers.indexY &+= 1
        updateZeroNegativeFlags(for: registers.indexY)
    }

    /// Decrement X Register:
    /// Subtracts one from the X index register.
    /// - Note: Updates zero and negative flags based on the result.
    ///   DEX affects flags:
    ///     - Zero (Z): Set if X becomes zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of X is set, cleared otherwise
    func dex() {
        emuLogger.debug("dex")
        
        registers.indexX &-= 1
        updateZeroNegativeFlags(for: registers.indexX)
    }
    
    /// Compare and Subtract from X (SBX, SAX):
    /// "Illegal" Opcode.
    /// Performs (A AND X) - parameter, stores the result in X, and sets flags like CMP.
    func axs(value: UInt8) {
        emuLogger.debug("axs")
        
        let andResult = registers.accumulator & registers.indexX
        let subtractedResult = andResult &- value
        
        registers.indexX = subtractedResult
        
        registers.status.setFlag(.carry, to: andResult >= value)
        registers.status.setFlag(.zero, to: subtractedResult == 0)
        registers.status.setFlag(.negative, to: (subtractedResult & .mostSignificantBit) != 0)
    }
    
    /// Branch if Not Equal:
    /// If the zero flag is not set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func bne(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("bne")
        
        if !registers.status.readFlag(.zero) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Clear Decimal Mode:
    // TODO: - Support Decimal mode
    func cld() {
        emuLogger.debug("cld")
        
        registers.status.setFlag(.decimal, to: false)
    }
    
    /// Compare X Register:
    /// Compares the contents of the X register with a specified value and sets the zero, carry, and negative flags based on the result.
    /// - Parameters:
    ///   - value: The value to compare with the X register.
    func cpx(value: UInt8) {
        emuLogger.debug("cpx")
        
        let result = Int(registers.indexX) - Int(value)
        
        registers.status.setFlag(.carry, to: registers.indexX >= value)
        registers.status.setFlag(.zero, to: registers.indexX == value)
        registers.status.setFlag(.negative, to: (result & 0x80) != 0)
    }
    
    /// Subtract with Carry:
    /// Subtracts the provided byte value and the inverted carry flag from the accumulator.
    /// (A - M - (1 - C)) is the same as (A + ~M + C)
    /// Updates the zero, carry, overflow, and negative flags based on the result.
    /// - Parameter value: The byte value to subtract from the accumulator
    func sbc(value: UInt8) {
        emuLogger.debug("sbc")
        
        let initialAccumulator = registers.accumulator // Save for overflow check
        
        let inverseCarry = registers.status.readFlag(.carry) ? 0 : 1
        let fullResult = Int(registers.accumulator) - Int(value) - inverseCarry
        
        // Update accumulator with truncated result
        registers.accumulator = UInt8(bitPattern: Int8(truncatingIfNeeded: fullResult))
        
        updateZeroNegativeFlags()
        registers.status.setFlag(.carry, to: fullResult >= 0)
        
        // Check overflow using inputs and final result
        let overflow = ((initialAccumulator ^ registers.accumulator) &
                        (initialAccumulator ^ value) & .mostSignificantBit) != 0
        registers.status.setFlag(.overflow, to: overflow)
    }
    /// INC oper + SBC oper:
    /// "Illegal" Opcode.
    /// Increments the value at the specified memory location by one, then subtracts the result from the accumulator
    /// along with the carry flag, updating the accumulator and flags accordingly (zero, negative, carry, overflow).
    func isc(value: inout UInt8) {
        emuLogger.debug("isc")
        
        inc(value: &value)
        sbc(value: value)
    }
    
    /// Increment Memory:
    /// Updates the zero and negative flags based on the result.
    func inc(value: inout UInt8) {
        emuLogger.debug("inc")
        
        value &+= 1
        updateZeroNegativeFlags(for: value)
    }
    
    /// Increment X Register:
    /// Adds one to the X index register.
    /// - Note: Updates zero and negative flags based on the result.
    ///   INX affects flags:
    ///     - Zero (Z): Set if X becomes zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of X is set, cleared otherwise
    func inx() {
        emuLogger.debug("inx")
        
        registers.indexX &+= 1
        updateZeroNegativeFlags(for: registers.indexX)
    }
    
    /// Branch if Equal
    /// If the negative flag is clear then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Returns: A tuple containing whether a branch occurred and whether a page boundary was crossed
    func beq(value: UInt8) -> (didBranch: Bool, didCrossPageBoundary: Bool) {
        emuLogger.debug("beq")
        
        if registers.status.readFlag(.zero) {
            let offset = Int16(Int8(bitPattern: value))
            let newOffsetSigned = Int16(bitPattern: registers.programCounter) &+ offset
            let newPC = UInt16(bitPattern: newOffsetSigned)
            
            let willCross = (registers.programCounter & 0xFF00) != (newPC & 0xFF00)
            
            registers.programCounter = UInt16(bitPattern: newOffsetSigned)
            
            return (true, willCross)
        }
        
        return (false, false)
    }
    
    /// Set Decimal Flag:
    // TODO: - Support Decimal mode
    func sed() {
        emuLogger.debug("sed")
        
        registers.status.setFlag(.decimal, to: true)
    }
}
