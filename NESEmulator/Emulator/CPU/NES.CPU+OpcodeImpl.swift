
/// Opcodes only handle the cycle count for the current instruction, and not for fetching the opcode nor handling the addressing mode
extension NES.CPU {
    /// Break:
    /// Pushes the program counter and processor status to the stack.
    /// Loads the interrupt vector from 0xFFFE/F into the program counter.
    /// Sets the break flag status to 1 (in both the active status and the status pushed to the stack).
    /// - Note: This function increments the clock cycle count by 6 (instead of the expected 7) due to the run function incrementing the clock cycle when fetching the opcode
    func brk() {
        emuLogger.debug("brk")
        
        registers.status.setFlag(.break, to: true)
        
        push(UInt8((registers.programCounter >> 8) & 0xFF))
        push(UInt8(registers.programCounter & 0xFF))
        push(registers.status.rawValue)
        
        let lowByte = UInt16(memoryManager.read(from: 0xFFFE))
        let highByte = UInt16(memoryManager.read(from: 0xFFFF))
        
        registers.programCounter = lowByte | (highByte << 8)
        
        clockCycleCount += 6
    }
    
    /// Logical Inclusive OR:
    /// Performs a bitwise OR operation, bit by bit, on the accumulator with the value fetched using the specified addressing mode.
    /// - Parameter value: The value fetched using the specified addressing mode to be ORed with the accumulator
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
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
        fatalError("Illegal opcode 'stp/kil/jam' encountered. This is an unreachable state and indicates a severe error in the emulator.")
    }
    
    /// Shift Left Logical OR:
    /// Shifts all bits in the value one place to the left and then ORs the accumulator with the result.
    /// - Parameter value: The value to perform the SLO operation on
    /// - Note: This function increments the clock cycle count by 1 (instead of the expected 5) due to the run function and addressing mode functions incrementing the cycle count
    func slo(value: inout UInt8) {
        emuLogger.debug("slo")
        
        asl(value: &value)
        ora(value: value)
    }
    
    /// No Operation:
    /// Burns one clock cycle (or two, including the opcode pulled from memory).
    func nop() {
        emuLogger.debug("nop")
        
        clockCycleCount += 1
    }
    
    /// Accumulator Shift Left:
    /// Shifts the accumulator left 1 bit and updates carry, zero, and negative flags.
    /// - Note: This function increments the clock cycle count by 1 (instead of the expected 2 or 5+ based on addressing mode) due to the run function and addressing mode functions incrementing the cycle count
    func asl(value: inout UInt8, isAccumulator: Bool = false) {
        emuLogger.debug("asl")
        
        // Check for carry before performing shift
        let carryFlag = Registers.Status.carry
        registers.status.setFlag(carryFlag, to: value & .mostSignificantBit != 0)
        
        value <<= 1
        
        updateZeroNegativeFlags(for: value)
        
        clockCycleCount += isAccumulator ? 1 : 2
    }
    
    /// Push Processor Status:
    /// Pushes the current status register (processor status) onto the stack with the break flag and bit 5 set to 1.
    /// Updates the stack pointer.
    /// - Note: Increments the clock cycle count by 2 (instead of the expected 3) due to the run function incrementing the cycle count
    func php() {
        emuLogger.debug("php")
        
        // Bit 5 is overridden in this context
        push(registers.status.rawValue | Registers.Status.break.rawValue)
        
        clockCycleCount += 2
    }
    
    /// AND with Carry:
    /// Performs a bitwise AND between the accumulator and the specified value, and then sets the carry flag to the same value as bit 7 of the result.
    /// - Parameter value: The value to perform the AND operation with the accumulator.
    func anc(value: UInt8) {
        emuLogger.debug("anc")
        
        and(value: value)
        
        let carryFlag = Registers.Status.carry
        registers.status.setFlag(carryFlag, to: registers.accumulator & .mostSignificantBit != 0)
    }
    
    /// Branch if Positive:
    /// If the negative flag is clear then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    func bpl(value: UInt8) {
        emuLogger.debug("bpl")
        
        if !registers.status.readFlag(.negative) {
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
    }
    
    /// Clear Carry Flag:
    /// - Note: This function increments the clock cycle count by 1 (instead of the expected 2) due to the run function and addressing mode functions incrementing the cycle count
    func clc() {
        emuLogger.debug("clc")
        
        registers.status.setFlag(.carry, to: false)
        clockCycleCount += 1
    }
    
    /// Jump to Subroutine:
    /// Pushes the address of the return point on to the stack and then sets the program counter to the target memory address.
    /// - Note: Increments the clock cycle count by 3 (instead of the expected 6) due to the run function and addressing mode functions incrementing the cycle count
    func jsr(value: UInt16) {
        emuLogger.debug("jsr")
        
        push(UInt8((registers.programCounter >> 8) & 0xFF))
        push(UInt8(registers.programCounter & 0xFF))
        
        registers.programCounter = value
        
        clockCycleCount += 3
    }
    
    /// And:
    /// Performs a bitwise AND operation between the accumulator and the provided value.
    /// Updates the zero and negative flags.
    /// - Note: Clock cycle is not incrmented as AND takes 2 cycles total, one for fetching the opcode, and one for fetching the value
    func and(value: UInt8) {
        registers.accumulator &= value
        updateZeroNegativeFlags()
        
        emuLogger.debug("and")
    }
    
    /// Rotate Left + And:
    /// An "Illegal" Opcode.
    /// - Note: Cycles are handled by `rol` call
    func rla(value: inout UInt8) {
        rol(value: &value)
        and(value: value)
    }
    
    /// Test Bits in Memory with Accumulator:
    /// Transfer bits 7 and 6 of operand to bit 7 and 6 of SR (N,V).
    /// The zero-flag is set according to the result of the operand AND the accumulator (set, if the result is zero, unset otherwise).
    /// This allows a quick check of a few bits at once without affecting any of the registers, other than the status register (SR).
    /// - Note: No cycles are added because fetching the opcode and addressing mode function handles all cycles
    func bit(value: UInt8) {
        emuLogger.debug("bit")

        registers.status.setFlag(.negative, to: (value & .mostSignificantBit) != 0)
        registers.status.setFlag(.overflow, to: (value & 0b01000000) != 0)
        registers.status.setFlag(.zero, to: (registers.accumulator & value) == 0)
    }
    
    /// Rotate Left:
    /// Shifts all bits in the value one place to the left.
    /// Carry flag becomes bit 0 while the old bit 7 becomes the new carry flag.
    /// - Note: Added cycle count is based on whether operating on accumulator register or not
    func rol(value: inout UInt8, isAccumulator: Bool = false) {
        emuLogger.debug("rol")
        
        let carryFlag = Registers.Status.carry
        let newCarry = (value & .mostSignificantBit) != 0
        value <<= 1
        value |= registers.status.readFlag(carryFlag) ? 1 : 0
        registers.status.setFlag(carryFlag, to: newCarry)
        
        updateZeroNegativeFlags(for: value)
        clockCycleCount += isAccumulator ? 1 : 2
    }
    
    /// Pull Processor Status:
    /// Pulls an 8 bit value from the stack and into the processor status register (SR).
    /// - Note: Clock cycle incremented by 3 (instead of the expected 4) due to the run function incrementing the cycle count
    func plp() {
        emuLogger.debug("plp")
        
        registers.status.rawValue = pop()
        
        clockCycleCount += 3
    }
    
    /// Branch if Minus (Negative):
    /// If the negative flag is set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed
    func bmi(value: UInt8) {
        emuLogger.debug("bmi")
        
        if registers.status.readFlag(.negative) {
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
    }
    
    /// Set Carry Flag:
    /// - Note: Clock cycle incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func sec() {
        emuLogger.debug("sec")
        
        registers.status.setFlag(.carry, to: true)
        clockCycleCount += 1
    }
    
    /// Return from Interrupt:
    /// Pulls the processor status register and the program counter from the stack.
    /// - Note: Clock cycle incremented by 5 (instead of the expected 6) due to the run function incrementing the cycle count
    func rti() {
        emuLogger.debug("rti")
        
        let status = pop()
        registers.status.rawValue = status & ~Registers.Status.break.rawValue
        
        let lowByte = UInt16(pop())
        let highByte = UInt16(pop()) << 8
        
        registers.programCounter = lowByte | highByte
        
        clockCycleCount += 5
    }
    
    /// Exclusive-OR (XOR):
    /// An exclusive OR is performed, bit by bit, on the accumulator register using the provided value.
    /// The result is stored back into the accumulator.
    /// - Note: No cycles are added because fetching the opcode and addressing mode function handles all cycles
    func eor(value: UInt8) {
        emuLogger.debug("eor")
        
        registers.accumulator ^= value
        
        updateZeroNegativeFlags()
    }
    
    /// LSR + EOR:
    /// An "Illegal" Opcode.
    /// Shifts all bits in the value one place to the right, then XORs the result with the accumulator.
    /// - Note: No cycles are added because calling lsr as well as run function and addressing mode function handles all cycles
    func sre(value: inout UInt8) {
        emuLogger.debug("sre")
        
        lsr(value: &value)
        eor(value: value)
    }
    
    /// Logical Shift Right:
    /// Shifts all bits in the value one place to the right, storing the old bit 0 in the carry flag.
    /// - Note: Added cycle count is based on whether operating on accumulator register or not
    func lsr(value: inout UInt8, isAccumulator: Bool = false) {
        emuLogger.debug("lsr")
        
        let newCarry = (value & 1) != 0
        
        value >>= 1
        
        registers.status.setFlag(.carry, to: newCarry)
        updateZeroNegativeFlags(for: value)
        
        clockCycleCount += isAccumulator ? 1 : 2
    }
    
    /// Push Accumulator:
    /// Pushes the contents of the accumulator on to the stack.
    /// - Note: Clock cycle incremented by 2 (instead of the expected 3) due to the run function incrementing the cycle count
    func pha() {
        emuLogger.debug("pha")
        
        push(registers.accumulator)
        
        clockCycleCount += 2
    }
    
    /// AND + Logical Shift Right:
    /// An "Illegal" Opcode.
    /// - Note: No cycles are added because run function and addressing mode function handles all cycles
    func alr(value: UInt8) {
        emuLogger.debug("alr")
        
        and(value: value)
        
        // Re-implement LSR with no cycles
        let carry = registers.accumulator & 0x01 // Save the original carry before shifting
        registers.accumulator >>= 1
        registers.status.setFlag(.carry, to: carry != 0)
        
        // Update zero and negative flags
        updateZeroNegativeFlags(for: registers.accumulator)
    }
    
    /// Jump:
    /// The program counter is set to the address specified by the operand.
    /// - Note: 1 cycle is removed, as jmp takes 3 cycles for abs and 5 for indirect. Because incrementing PC takes one cycle, one is removed to equalize
    func jmp(value: UInt16) {
        emuLogger.debug("jmp")
        
        registers.programCounter = value
        
        clockCycleCount -= 1
    }
    
    /// Branch if Overflow Clear:
    /// If the negative flag is clear then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    func bvc(value: UInt8) {
        emuLogger.debug("bvc")
        
        if !registers.status.readFlag(.overflow) {
            // TODO: - Fix potential issue with int conversion:
            // let offset = UInt16(bitPattern: Int16(Int8(bitPattern: value)))
            // let newAddress = registers.programCounter + offset
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
    }
    
    /// Clear Interrupt Flag:
    /// Clears the interrupt disable flag in the processor status register, allowing the CPU to respond to interrupts.
    /// - Note: Increments the clock cycle count by 1 (instead of the expected 2) due to the run function incrementing the cycle count.
    func cli() {
        emuLogger.debug("cli")
        
        registers.status.setFlag(.interrupt, to: false)
        clockCycleCount += 1
    }
    
    /// Return from Subroutine:
    /// Restores the program counter (PC) to the address on the stack, then increments the PC to the address following the original subroutine call.
    /// - Note: Increments the clock cycle count by 5 (instead of the expected 6) due to the run function incrementing the cycle count.
    func rts() {
        emuLogger.debug("rts")
        
        let low = UInt16(pop())
        let high = UInt16(pop()) << 8
        
        let value = high | low
        
        registers.programCounter = value
        clockCycleCount += 5
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
        registers.status.setFlag(.negative, to: newAccumulator & 0x80 != 0)
        registers.status.setFlag(.overflow, to: ((registers.accumulator ^ newAccumulator) & (value ^ newAccumulator) & 0x80) != 0)
        
        registers.accumulator = newAccumulator
    }
    
    /// ROR + ADC:
    /// An "Illegal" Opcode.
    /// - Note: Adds 2 cycles on top of cycles added from ror
    func rra(value: inout UInt8) {
        emuLogger.debug("rra")
        
        ror(value: &value)
        adc(value: value)
        
        clockCycleCount += 2
    }
    
    /// Rotate Right:
    /// Shifts all bits in the value one place to the right.
    /// Carry flag becomes bit 7 while the old bit 0 becomes the new carry flag.
    /// - Note: Added cycle count is based on whether operating on accumulator register or not
    func ror(value: inout UInt8, isAccumulator: Bool = false) {
        emuLogger.debug("ror")
        
        let carryFlag = Registers.Status.carry
        let newCarry = (value & 0x1) != 0
        value >>= 1
        value |= registers.status.readFlag(carryFlag) ? .mostSignificantBit : 0
        registers.status.setFlag(carryFlag, to: newCarry)
        
        updateZeroNegativeFlags(for: value)
        clockCycleCount += isAccumulator ? 1 : 2
    }
    
    /// Pull Accumulator:
    /// Pulls an 8 bit value from the stack and into the accumulator.
    /// - Note: Increments the clock cycle count by 3 (instead of the expected 4) due to the run function incrementing the cycle count
    func pla() {
        emuLogger.debug("pla")
        
        let value = pop()
        
        registers.accumulator = value
        updateZeroNegativeFlags(for: value)
        
        clockCycleCount += 3
    }
    
    /// AND + ROR:
    /// An "Illegal" Opcode.
    /// - Note: Increments the clock cycle count by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    // TODO: - Verify implementation (sources conflict on how ARR should be implemented):
    // https://www.nesdev.org/wiki/Programming_with_unofficial_opcodes
    // https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes#ARR
    // https://c74project.com/wp-content/uploads/2020/04/c74-6502-undocumented-opcodes.pdf
    func arr(value: inout UInt8) {
        emuLogger.debug("arr")
        
        // Perform AND operation
        let result = registers.accumulator & value
        
        // Rotate right by one bit
        let oldCarry: UInt8 = registers.status.readFlag(.carry) ? 1 : 0
        let newCarry = (result & 0x40) != 0
        let rotatedResult = (result >> 1) | (oldCarry << 7)
        
        // Update flags
        updateZeroNegativeFlags(for: rotatedResult)
        registers.status.setFlag(.carry, to: newCarry) // Set C to bit 6
        let vFlag = ((result & 0x40) ^ (result & 0x20)) != 0 // Calculate V as bit 6 XOR bit 5
        registers.status.setFlag(.overflow, to: vFlag)
        
        // Update accumulator with the result
        registers.accumulator = rotatedResult
        
        clockCycleCount += 1
    }
    
    /// Branch is Overflow Set:
    /// If the overflow flag is set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    func bvs(value: UInt8) {
        emuLogger.debug("bvs")
        
        if registers.status.readFlag(.overflow) {
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
    }
    
    /// Set Interrupt Disable:
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func sei() {
        emuLogger.debug("sei")
        
        registers.status.setFlag(.interrupt, to: true)
        clockCycleCount += 1
    }
    
    /// Store Accumulator:
    /// Stores the value of the accumulator at the specified memory address.
    /// - Parameters:
    ///   - value: The memory address where the register's value will be stored.
    /// - Note: No cycles are added because fetching the opcode and addressing mode function handles all cycles
    func sta(value address: UInt16) {
        emuLogger.debug("sta")
        
        memoryManager.write(registers.accumulator, to: address)
    }
    
    /// AND Accumulator + indexX, then store result at the specified memory address:
    /// Illegal Opcode.
    /// - Note: No cycles are added because fetching the opcode and addressing mode function handles all cycles
    func sax(value address: UInt16) {
        emuLogger.debug("sax")
        
        let result = registers.accumulator & registers.indexX
        memoryManager.write(result, to: address)
    }
    
    /// Store Y Register:
    /// Stores the value of the y register at the specified memory address.
    /// - Parameters:
    ///   - value: The memory address where the register's value will be stored.
    /// - Note: No cycles are added because fetching the opcode and addressing mode function handles all cycles
    func sty(value address: UInt16) {
        emuLogger.debug("sty")
        
        memoryManager.write(registers.indexY, to: address)
    }
    
    /// Store X Register:
    /// Stores the value of the x register at the specified memory address.
    /// - Parameters:
    ///   - value: The memory address where the register's value will be stored.
    /// - Note: No cycles are added because fetching the opcode and addressing mode function handles all cycles
    func stx(value address: UInt16) {
        emuLogger.debug("stx")
        
        memoryManager.write(registers.indexX, to: address)
    }
    
    /// Decrement Y Register:
    /// Updates the zero and negative flags based on the result.
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func dey() {
        emuLogger.debug("dey")
        
        registers.indexY &-= 1
        clockCycleCount += 1
    }
    
    /// Transfer X to Accumulator:
    /// Updates the zero and negative flags based on the result.
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func txa() {
        emuLogger.debug("txa")
        
        registers.accumulator = registers.indexX
        updateZeroNegativeFlags()
        
        clockCycleCount += 1
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
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    func bcc(value: UInt8) {
        emuLogger.debug("bcc")
        
        if !registers.status.readFlag(.carry) {
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
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
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func tya() {
        emuLogger.debug("tya")
        
        registers.accumulator = registers.indexY
        updateZeroNegativeFlags()
        
        clockCycleCount += 1
    }
    
    /// Transfer X to Stack Pointer:
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func txs() {
        emuLogger.debug("txs")
        
        registers.stackPointer = registers.indexX
        
        clockCycleCount += 1
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
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
    func ldy(value: UInt8) {
        emuLogger.debug("ldy")
        
        registers.indexY = value
        updateZeroNegativeFlags(for: value)
    }
    
    /// Load Accumulator Register:
    /// Sets the zero and negative flags.
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
    func lda(value: UInt8) {
        emuLogger.debug("lda")
        
        registers.accumulator = value
        
        updateZeroNegativeFlags()
    }
    
    /// Load X Register:
    /// Sets the zero and negative flags.
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
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
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func tay() {
        emuLogger.debug("tay")
        
        registers.indexY = registers.accumulator
        updateZeroNegativeFlags(for: registers.indexY)
        
        clockCycleCount += 1
    }
    
    /// Transfer Accumulator to X:
    /// Sets zero and negative flags.
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func tax() {
        emuLogger.debug("tax")
        
        registers.indexX = registers.accumulator
        updateZeroNegativeFlags(for: registers.indexX)
        
        clockCycleCount += 1
    }
    
    /// Branch if Carry Set:
    /// If the carry flag is set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    func bcs(value: UInt8) {
        emuLogger.debug("bcs")
        
        if registers.status.readFlag(.carry) {
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
    }
    
    /// Clear Overflow Flag:
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func clv() {
        emuLogger.debug("clv")
        
        registers.status.setFlag(.overflow, to: false)
        
        clockCycleCount += 1
    }
    
    /// Transfer Stack Pointer to X:
    /// Sets the zero and negative flags.
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func tsx() {
        emuLogger.debug("tsx")
        
        registers.indexX = registers.stackPointer
        
        clockCycleCount += 1
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
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
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
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
    func cmp(value: UInt8) {
        emuLogger.debug("cmp")
        
        let result = Int(registers.accumulator) - Int(value)
        
        registers.status.setFlag(.carry, to: registers.accumulator >= value)
        registers.status.setFlag(.zero, to: registers.accumulator == value)
        registers.status.setFlag(.negative, to: (result & 0x80) != 0)
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
        registers.status.setFlag(.negative, to: (result & 0x80) != 0)
    }
    
    /// Decrement Memory:
    /// Subtracts one from the value at the specified memory location.
    /// - Parameter value: Memory location to decrement, passed by reference
    /// - Note: Updates zero and negative flags based on the result.
    ///   Takes 2 cycles (not including opcode fetch and addressing mode).
    ///   DEC affects flags:
    ///     - Zero (Z): Set if result is zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of result is set, cleared otherwise
    func dec(value: inout UInt8) {
        emuLogger.debug("dec")
        
        value &-= 1
        
        updateZeroNegativeFlags(for: value)
        
        clockCycleCount += 2
    }

    /// Increment Y Register:
    /// Adds one to the Y index register.
    /// - Note: Updates zero and negative flags based on the result.
    ///   Takes 1 cycle (not including opcode fetch).
    ///   INY affects flags:
    ///     - Zero (Z): Set if Y becomes zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of Y is set, cleared otherwise
    func iny() {
        emuLogger.debug("iny")
        
        registers.indexY &+= 1
        updateZeroNegativeFlags(for: registers.indexY)
        
        clockCycleCount += 1
    }

    /// Decrement X Register:
    /// Subtracts one from the X index register.
    /// - Note: Updates zero and negative flags based on the result.
    ///   Takes 1 cycle (not including opcode fetch).
    ///   DEX affects flags:
    ///     - Zero (Z): Set if X becomes zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of X is set, cleared otherwise
    func dex() {
        emuLogger.debug("dex")
        
        registers.indexX &-= 1
        updateZeroNegativeFlags(for: registers.indexX)
        
        clockCycleCount += 1
    }
    
    /// Compare and Subtract from X (SBX, SAX):
    /// "Illegal" Opcode.
    /// Performs (A AND X) - parameter, stores the result in X, and sets flags like CMP.
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
    func axs(value: UInt8) {
        emuLogger.debug("axs")
        
        let andResult = registers.accumulator & registers.indexX
        let subtractedResult = andResult &- value
        
        registers.indexX = subtractedResult
        
        registers.status.setFlag(.carry, to: andResult >= value)
        registers.status.setFlag(.zero, to: subtractedResult == 0)
        registers.status.setFlag(.negative, to: (subtractedResult & 0x80) != 0)
    }
    
    /// Branch if Not Equal:
    /// If the zero flag is not set then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    func bne(value: UInt8) {
        emuLogger.debug("bne")
        
        if !registers.status.readFlag(.zero) {
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
    }
    
    /// Clear Decimal Mode:
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    // TODO: - Support Decimal mode
    func cld() {
        emuLogger.debug("cld")
        
        registers.status.setFlag(.decimal, to: false)
        
        clockCycleCount += 1
    }
    
    /// Compare X Register:
    /// Compares the contents of the X register with a specified value and sets the zero, carry, and negative flags based on the result.
    /// - Parameters:
    ///   - value: The value to compare with the X register.
    /// - Note: No cycles are added to `clockCycleCount` due to the run function and addressing mode functions incrementing the cycle count
    func cpx(value: UInt8) {
        emuLogger.debug("cpx")
        
        let result = Int(registers.indexX) - Int(value)
        
        registers.status.setFlag(.carry, to: registers.indexX >= value)
        registers.status.setFlag(.zero, to: registers.indexX == value)
        registers.status.setFlag(.negative, to: (result & 0x80) != 0)
    }
    
    /// Subtract with Carry:
    /// Subtracts the provided byte value and the inverted carry flag from the accumulator.
    /// Updates the zero, carry, overflow, and negative flags based on the result.
    /// - Parameter value: The byte value to subtract from the accumulator.
    func sbc(value: UInt8) {
        emuLogger.debug("sbc")
        
        let inverseCarry = registers.status.readFlag(.carry) ? 0 : 1
        let result = Int(registers.accumulator) - Int(value) - inverseCarry
        
        registers.accumulator = UInt8(truncatingIfNeeded: result)
        updateZeroNegativeFlags()
        registers.status.setFlag(.carry, to: result >= 0)
        
        let overflow = (registers.accumulator ^ UInt8(result)) & (UInt8(result) ^ value) & 0x80
        registers.status.setFlag(.overflow, to: overflow != 0)
    }
    
    /// INC oper + SBC oper:
    /// "Illegal" Opcode.
    /// Increments the value at the specified memory location by one, then subtracts the result from the accumulator
    /// along with the carry flag, updating the accumulator and flags accordingly (zero, negative, carry, overflow).
    /// - Note: Clock cycle count is incremented by 2 as run function and addressing mode functions handle other cycles.
    func isc(value: inout UInt8) {
        emuLogger.debug("isc")
        
        value &+= 1
        
        let carryValue = registers.status.readFlag(.carry) ? 1 : 0
        let result = Int(registers.accumulator) - Int(value) - carryValue
        
        registers.accumulator -= value + (registers.status.readFlag(.carry) ? 0 : 1)
        
        registers.accumulator = UInt8(truncatingIfNeeded: result)
        updateZeroNegativeFlags()
        registers.status.setFlag(.carry, to: result >= 0)
        
        let overflow = ((registers.accumulator ^ UInt8(result)) & (value ^ UInt8(result)) & 0x80) != 0
        registers.status.setFlag(.overflow, to: overflow)
        
        clockCycleCount += 2
    }
    
    /// Increment Memory:
    /// Updates the zero and negative flags based on the result.
    /// - Note: Cycle count is incremented by 1 (instead of the expected 2) due to the run function incrementing the cycle count
    func inc(value: inout UInt8) {
        emuLogger.debug("inc")
        
        value &+= 1
        updateZeroNegativeFlags(for: value)
        
        clockCycleCount += 1
    }
    
    /// Increment X Register:
    /// Adds one to the X index register.
    /// - Note: Updates zero and negative flags based on the result.
    ///   Takes 1 cycle (not including opcode fetch).
    ///   INX affects flags:
    ///     - Zero (Z): Set if X becomes zero, cleared otherwise
    ///     - Negative (N): Set if bit 7 of X is set, cleared otherwise
    func inx() {
        emuLogger.debug("inx")
        
        registers.indexX &+= 1
        updateZeroNegativeFlags(for: registers.indexX)
        
        clockCycleCount += 1
    }
    
    /// Branch if Equal
    /// If the negative flag is clear then add the relative displacement to the program counter to cause a branch to a new location.
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    func beq(value: UInt8) {
        emuLogger.debug("beq")
        
        if registers.status.readFlag(.zero) {
            let offset = Int8(bitPattern: value)
            let newAddress = UInt16(Int16(registers.programCounter) + Int16(offset))
            if (registers.programCounter & 0xFF00) != (newAddress & 0xFF00) {
                clockCycleCount += 1 // Add cycle when crossing page boundary
            }
            
            registers.programCounter = newAddress
            clockCycleCount += 1 // Add cycle when branch is successful
        }
    }
    
    /// Set Decimal Flag:
    /// - Note: Cycle count is incremented if branch succeeds, and is incremented again if page boundary is crossed.
    // TODO: - Support Decimal mode
    func sed() {
        emuLogger.debug("sed")
        
        registers.status.setFlag(.decimal, to: true)
        
        clockCycleCount += 1
    }
}
