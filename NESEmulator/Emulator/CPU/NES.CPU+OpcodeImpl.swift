
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
        let carryFlag = Registers.Status.Flag.carry
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
        
        // Bit 5 is ignored in this context
        push(registers.status.rawValue | Registers.Status.Flag.break.rawValue)
        
        clockCycleCount += 2
    }
    
    /// AND with Carry:
    /// Performs a bitwise AND between the accumulator and the specified value, and then sets the carry flag to the same value as bit 7 of the result.
    /// - Parameter value: The value to perform the AND operation with the accumulator.
    func anc(value: UInt8) {
        emuLogger.debug("anc")
        
        and(value: value)
        
        let carryFlag = Registers.Status.Flag.carry
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
    /// - Note:
    func rol(value: inout UInt8, isAccumulator: Bool = false) {
        emuLogger.debug("rol")
        
        let carryFlag = Registers.Status.Flag.carry
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
        registers.status.rawValue = status & ~Registers.Status.Flag.break.rawValue
        
        let lowByte = UInt16(pop())
        let highByte = UInt16(pop()) << 8
        
        registers.programCounter = lowByte | highByte
        
        clockCycleCount += 5
    }
    
    func eor() {
        emuLogger.debug("eor")
    }
    
    func sre() {
        emuLogger.debug("sre")
    }
    
    func lsr() {
        emuLogger.debug("lsr")
    }
    
    func pha() {
        emuLogger.debug("pha")
    }
    
    func alr() {
        emuLogger.debug("alr")
    }
    
    func jmp() {
        emuLogger.debug("jmp")
    }
    
    func bvc() {
        emuLogger.debug("bvc")
    }
    
    func cli() {
        emuLogger.debug("cli")
    }
    
    func rts() {
        emuLogger.debug("rts")
    }
    
    func adc() {
        emuLogger.debug("adc")
    }
    
    func rra() {
        emuLogger.debug("rra")
    }
    
    func ror() {
        emuLogger.debug("ror")
    }
    
    func pla() {
        emuLogger.debug("pla")
    }
    
    func arr() {
        emuLogger.debug("arr")
    }
    
    func bvs() {
        emuLogger.debug("bvs")
    }
    
    func sei() {
        emuLogger.debug("sei")
    }
    
    func sta() {
        emuLogger.debug("sta")
    }
    
    func sax() {
        emuLogger.debug("sax")
    }
    
    func sty() {
        emuLogger.debug("sty")
    }
    
    func stx() {
        emuLogger.debug("stx")
    }
    
    func dey() {
        emuLogger.debug("dey")
    }
    
    func txa() {
        emuLogger.debug("txa")
    }
    
    func xaa() {
        emuLogger.debug("xaa")
    }
    
    func bcc() {
        emuLogger.debug("bcc")
    }
    
    func ahx() {
        emuLogger.debug("ahx")
    }
    
    func tya() {
        emuLogger.debug("tya")
    }
    
    func txs() {
        emuLogger.debug("txs")
    }
    
    func tas() {
        emuLogger.debug("tas")
    }
    
    func shy() {
        emuLogger.debug("shy")
    }
    
    func shx() {
        emuLogger.debug("shx")
    }
    
    func ldy() {
        emuLogger.debug("ldy")
    }
    
    func lda() {
        emuLogger.debug("lda")
    }
    
    func ldx() {
        emuLogger.debug("ldx")
    }
    
    func lax() {
        emuLogger.debug("lax")
    }
    
    func tay() {
        emuLogger.debug("tay")
    }
    
    func tax() {
        emuLogger.debug("tax")
    }
    
    func bcs() {
        emuLogger.debug("bcs")
    }
    
    func clv() {
        emuLogger.debug("clv")
    }
    
    func tsx() {
        emuLogger.debug("tsx")
    }
    
    func las() {
        emuLogger.debug("las")
    }
    
    func cpy() {
        emuLogger.debug("cpy")
    }
    
    func cmp() {
        emuLogger.debug("cmp")
    }
    
    func dcp() {
        emuLogger.debug("dcp")
    }
    
    func dec() {
        emuLogger.debug("dec")
    }
    
    func iny() {
        emuLogger.debug("iny")
    }
    
    func dex() {
        emuLogger.debug("dex")
    }
    
    func axs() {
        emuLogger.debug("axs")
    }
    
    func bne() {
        emuLogger.debug("bne")
    }
    
    func cld() {
        emuLogger.debug("cld")
    }
    
    func cpx() {
        emuLogger.debug("cpx")
    }
    
    func sbc() {
        emuLogger.debug("sbc")
    }
    
    func isc() {
        emuLogger.debug("isc")
    }
    
    func inc() {
        emuLogger.debug("inc")
    }
    
    func inx() {
        emuLogger.debug("inx")
    }
    
    func beq() {
        emuLogger.debug("beq")
    }
    
    func sed() {
        emuLogger.debug("sed")
    }
}
