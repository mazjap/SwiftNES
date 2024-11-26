import Testing
@testable import NESEmulator

// Stack Operations (PHA, PHP, PLA, PLP, RTI)
@Suite("CPU Stack Operations")
class StackOpcodeTests: OpcodeTestBase {
    @Test("PHA - implied mode ✓")
    func PHA_implied() {
        var context = setupImplied(opcode: 0x48)
        let initialSP = context.cpu.registers.stackPointer
        
        context.cpu.registers.accumulator = 0x42
        context.expected.sp = initialSP - 1
        context.expected.a = 0x42
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        
        let pushedValue = context.mmu.read(from: 0x0100 + UInt16(initialSP))
        #expect(pushedValue == 0x42, "Accumulator value should be pushed to stack")
    }

    @Test("PHP - implied mode ✓")
    func PHP_implied() { // TODO: - Refactor CPU to always have status bit 5 set
        var context = setupImplied(opcode: 0x08)
        let initialSP = context.cpu.registers.stackPointer
        
        context.cpu.registers.status = Status([.carry, .zero, .overflow])
        context.expected.sp = initialSP - 1
        context.expected.status = Status([.carry, .zero, .overflow])
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        let pushedValue = context.mmu.read(from: 0x0100 + UInt16(initialSP))
        let expectedStatus = Status([.carry, .zero, .overflow, .break]).rawValue
        #expect(pushedValue == expectedStatus, "Status should be pushed with break flag set")
    }

    @Test("PLA - implied mode ✓")
    func PLA_implied() {
        var context = setupImplied(opcode: 0x68)
        let initialSP = context.cpu.registers.stackPointer
        
        // Push a test value onto stack first
        context.cpu.push(0x42)
        context.expected.a = 0x42 // Accumulator should get pulled value
        context.expected.sp = initialSP // SP should return to initial value
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        #expect(context.cpu.clockCycleCount == 4, "PLA should take 4 cycles")
    }

    @Test("PLA - Affects flags ✓")
    func PLA_flags() {
        // Test negative flag
        var context = setupImplied(opcode: 0x68)
        context.cpu.push(0x80)
        context.expected.status = Status.negative
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Test zero flag
        context = setupImplied(opcode: 0x68)
        context.cpu.push(0x00)
        context.expected.status = Status.zero
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("PLP - implied mode ✓")
    func PLP_implied() {
        var context = setupImplied(opcode: 0x28)
        let initialSP = context.cpu.registers.stackPointer
        
        // Push test status value with break (unused flag should also be set, but I'm ignoring it)
        let testStatus = Status([.carry, .zero, .overflow, .break]).rawValue
        context.cpu.push(testStatus)
        
        // Expected status should not include break flag
        context.expected.status = Status([.carry, .zero, .overflow])
        context.expected.sp = initialSP
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("RTI - implied mode ✓")
    func RTI_implied() {
        var context = setupImplied(opcode: 0x40)
        let initialSP = context.cpu.registers.stackPointer
        
        // Push return state (in reverse order as it would be during interrupt)
        let returnPC: UInt16 = 0x1234
        context.cpu.push(UInt8((returnPC >> 8) & 0xFF)) // PC high
        context.cpu.push(UInt8(returnPC & 0xFF)) // PC low
        let testStatus = Status([.carry, .zero, .overflow, .break]).rawValue
        context.cpu.push(testStatus)
        
        context.expected.status = Status([.carry, .zero, .overflow]) // Break flag ignored
        context.expected.sp = initialSP
        context.expected.pcStatus = .absolute(returnPC)
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("RTI - State restoration ✓")
    func RTI_stateRestoration() {
        let context = setupImplied(opcode: 0x40)
        
        // Setup initial state with all registers containing values
        context.cpu.registers.accumulator = 0x42
        context.cpu.registers.indexX = 0x24
        context.cpu.registers.indexY = 0x12
        let initialSP = context.cpu.registers.stackPointer
        
        // Push test state
        context.cpu.push(0x12)  // PC high
        context.cpu.push(0x34)  // PC low
        context.cpu.push(Status([.negative, .overflow]).rawValue)
        
        // Execute RTI
        context.cpu.executeNextInstruction()
        
        // Verify only PC and status were affected
        #expect(context.cpu.registers.programCounter == 0x1234, "PC should be restored")
        #expect(context.cpu.registers.status == Status([.negative, .overflow]), "Status should be restored")
        #expect(context.cpu.registers.accumulator == 0x42, "Accumulator should be unchanged")
        #expect(context.cpu.registers.indexX == 0x24, "X register should be unchanged")
        #expect(context.cpu.registers.indexY == 0x12, "Y register should be unchanged")
        #expect(context.cpu.registers.stackPointer == initialSP, "SP should reflect 3 pulls")
    }
}
