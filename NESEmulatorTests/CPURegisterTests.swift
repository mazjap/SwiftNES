import Testing
@testable import NESEmulator

@Suite("CPU Register Tests")
class CPURegisterTests: TestBase {
    
    // MARK: - Convenience
    
    func setupCPUState(pc: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: pc)
        return CPUTestContext(
            nes: nes,
            initialPC: pc,
            expected: ExpectedState(cycles: 0, pcIncrement: 0)
        )
    }
    
    // MARK: - Status Register Tests
    
    @Test("Status register flag operations")
    func testStatusFlags() {
        let context = setupCPUState()
        
        // Test individual flag setting/clearing
        context.cpu.registers.status.setFlag(.carry, to: true)
        #expect(context.cpu.registers.status.readFlag(.carry), "Flag should be set")
        
        context.cpu.registers.status.setFlag(.carry, to: false)
        #expect(!context.cpu.registers.status.readFlag(.carry), "Flag should be cleared")
        
        // Test multiple flags
        context.cpu.registers.status = Status([.carry, .zero])
        #expect(context.cpu.registers.status.readFlag(.carry) &&
               context.cpu.registers.status.readFlag(.zero),
               "Multiple flags should be settable")
    }
    
    // MARK: - Program Counter Tests
    
    @Test("PC handles instruction lengths")
    func testPCInstructionLength() {
        var context = setupCPUState()
        
        // One byte instruction (NOP)
        context.mmu.write(0xEA, to: 0x8000)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.programCounter == 0x8001)
        
        // Two byte instruction (LDA immediate)
        context = setupCPUState()
        context.mmu.write(0xA9, to: 0x8000)
        context.mmu.write(0x42, to: 0x8001)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.programCounter == 0x8002)
        
        // Three byte instruction (JMP absolute)
        context = setupCPUState()
        context.mmu.write(0x4C, to: 0x8000)
        context.mmu.write(0x34, to: 0x8001)
        context.mmu.write(0x12, to: 0x8002)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.programCounter == 0x1234)
    }
    
    // MARK: - Index Register Tests
    
    @Test("Index register operations")
    func testIndexRegisters() {
        var context = setupCPUState()
        
        // Test X register
        context.mmu.write(0xA2, to: 0x8000) // LDX immediate
        context.mmu.write(0x42, to: 0x8001)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.indexX == 0x42, "X register should load value")
        
        // Test Y register
        context = setupCPUState()
        context.mmu.write(0xA0, to: 0x8000) // LDY immediate
        context.mmu.write(0x42, to: 0x8001)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.indexY == 0x42, "Y register should load value")
    }

    @Test("Register interaction")
    func testRegisterInteraction() {
        var context = setupCPUState()
        
        // Test transfer instructions
        context.cpu.registers.accumulator = 0x42
        context.mmu.write(0xAA, to: 0x8000) // TAX
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.indexX == 0x42, "X should get A's value")
        
        context = setupCPUState()
        context.cpu.registers.indexX = 0x42
        context.mmu.write(0x8A, to: 0x8000) // TXA
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.accumulator == 0x42, "A should get X's value")
    }
    
    @Test("Flag updates from register operations")
    func testRegisterFlagUpdates() {
        var context = setupCPUState()
        
        // Load zero value - should set zero flag
        context.mmu.write(0xA9, to: 0x8000) // LDA immediate
        context.mmu.write(0x00, to: 0x8001)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status.contains(.zero), "Zero flag should be set")
        
        // Load negative value - should set negative flag
        context = setupCPUState()
        context.mmu.write(0xA9, to: 0x8000) // LDA immediate
        context.mmu.write(0x80, to: 0x8001)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status.contains(.negative), "Negative flag should be set")
    }
}
