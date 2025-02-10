import Testing
@testable import SwiftNES

@Suite("CPU Interrupt Tests")
class InterruptTests: TestBase {
    
    // MARK: - Convenience
    
    func setupCPUState(pc: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: pc)
        
        // Initialize test vectors
        nes.memoryManager.write(0xFA, to: 0xFFFA) // NMI low
        nes.memoryManager.write(0x10, to: 0xFFFB) // NMI high
        nes.memoryManager.write(0xFC, to: 0xFFFC) // Reset low
        nes.memoryManager.write(0x10, to: 0xFFFD) // Reset high
        nes.memoryManager.write(0xFE, to: 0xFFFE) // IRQ low
        nes.memoryManager.write(0x10, to: 0xFFFF) // IRQ high
        
        return CPUTestContext(
            nes: nes,
            initialPC: pc,
            expected: ExpectedState(cycles: 0, pcIncrement: 0)
        )
    }
    
    // MARK: - IRQ Tests
    
    @Test("Basic IRQ handling")
    func testBasicIRQ() {
        let context = setupCPUState()
        
        // Set up initial state
        context.mmu.write(0xAD, to: 0x8000) // LDA absolute
        context.mmu.write(0x00, to: 0x8001)
        context.mmu.write(0x20, to: 0x8002)
        
        let initialSP = context.cpu.registers.stackPointer
        
        context.cpu.triggerIRQ()
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x10FE, "IRQ should jump to interrupt vector")
        
        let pulledStatus = context.checkStack()
        let pulledPCLow = context.checkStack(back: 1)
        let pulledPCHigh = context.checkStack(back: 2)
        
        let pulledPC = UInt16(pulledPCHigh) << 8 | UInt16(pulledPCLow)
        
        #expect(pulledPC == 0x8003, "PC should be pushed with next instruction address")
        #expect(pulledStatus & Status.break.rawValue == 0, "Break flag should be clear in pushed status")
        
        #expect(context.cpu.registers.stackPointer == initialSP - 3, "Stack pointer should be decremented by 3")
        #expect(context.cpu.registers.status.contains(.interrupt), "Interrupt flag should be set")
        #expect(context.cpu.clockCycleCount == 4 + 7, "IRQ should add 7 cycles after instruction")
    }
    
    @Test("IRQ with interrupt disable flag")
    func testIRQDisabled() {
        let context = setupCPUState()
       
       // Set up initial state
       context.mmu.write(0xAD, to: 0x8000) // LDA absolute
       context.mmu.write(0x00, to: 0x8001)
       context.mmu.write(0x20, to: 0x8002)
       
       let initialSP = context.cpu.registers.stackPointer
       let initialPC = context.cpu.registers.programCounter
       
       context.cpu.registers.status.setFlag(.interrupt, to: true)
       context.cpu.triggerIRQ()
       context.cpu.executeNextInstruction()
       
       #expect(context.cpu.registers.stackPointer == initialSP, "Stack pointer should not change when IRQ is disabled")
       #expect(context.cpu.registers.programCounter == initialPC + 3, "PC should advance normally when IRQ is disabled")
       #expect(context.cpu.registers.status.contains(.interrupt), "Interrupt flag should remain set")
       #expect(context.cpu.clockCycleCount == 4, "Only instruction cycles should be counted")
    }
    
    @Test("IRQ timing")
    func testIRQTiming() {
        var context = setupCPUState()
        
        context.mmu.write(0xAD, to: 0x8000) // LDA absolute (4 cycles)
        context.mmu.write(0x00, to: 0x8001)
        context.mmu.write(0x20, to: 0x8002)
        
        context.cpu.triggerIRQ()
        let cycles = context.cpu.executeNextInstruction()
        
        #expect(cycles == 4 + 7, "IRQ should add 7 cycles after instruction completion")
        #expect(context.cpu.registers.programCounter == 0x10FE, "IRQ vector should be loaded after instruction completes")
        
        // Test with different instruction lengths
        context = setupCPUState()
        context.mmu.write(0x0A, to: 0x8000) // ASL A (2 cycles)
        context.cpu.triggerIRQ()
        let shortCycles = context.cpu.executeNextInstruction()
        #expect(shortCycles == 2 + 7, "IRQ should add 7 cycles after short instruction")
        
        context = setupCPUState()
        context.mmu.write(0x6C, to: 0x8000) // JMP indirect (5 cycles)
        context.mmu.write(0x00, to: 0x8001)
        context.mmu.write(0x20, to: 0x8002)
        context.cpu.triggerIRQ()
        let longCycles = context.cpu.executeNextInstruction()
        #expect(longCycles == 5 + 7, "IRQ should add 7 cycles after long instruction")
    }

    // MARK: - NMI Tests
    
    @Test("Basic NMI handling")
    func testBasicNMI() {
        let context = setupCPUState()
        
        // Set up initial state
        context.mmu.write(0xAD, to: 0x8000) // LDA absolute
        context.mmu.write(0x00, to: 0x8001)
        context.mmu.write(0x20, to: 0x8002)
        
        let initialSP = context.cpu.registers.stackPointer
        
        context.cpu.triggerNMI()
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x10FA, "NMI should jump to interrupt vector")
        
        let pulledStatus = context.checkStack()
        let pulledPCLow = context.checkStack(back: 1)
        let pulledPCHigh = context.checkStack(back: 2)
        
        let pulledPC = UInt16(pulledPCHigh) << 8 | UInt16(pulledPCLow)
        
        #expect(pulledPC == 0x8003, "PC should be pushed with next instruction address")
        #expect(pulledStatus & Status.break.rawValue == 0, "Break flag should be clear in pushed status")
        
        #expect(context.cpu.registers.stackPointer == initialSP - 3, "Stack pointer should be decremented by 3")
        #expect(context.cpu.registers.status.contains(.interrupt), "Interrupt flag should be set")
        #expect(context.cpu.clockCycleCount == 4 + 7, "NMI should add 7 cycles after instruction")
    }
    
    @Test("NMI occurs regardless of interrupt flag")
    func testNMINotMaskable() {
        let context = setupCPUState()
       
       // Set up initial state
       context.mmu.write(0xAD, to: 0x8000) // LDA absolute
       context.mmu.write(0x00, to: 0x8001)
       context.mmu.write(0x20, to: 0x8002)
       
       context.cpu.registers.status.setFlag(.interrupt, to: true)
       
       let initialSP = context.cpu.registers.stackPointer
       
       context.cpu.triggerNMI()
       context.cpu.executeNextInstruction()
       
       #expect(context.cpu.registers.programCounter == 0x10FA, "NMI should jump to interrupt vector even with interrupt flag set")
       #expect(context.cpu.registers.stackPointer == initialSP - 3, "Stack operations should occur despite interrupt flag")
       
       let pushedPC = UInt16(context.checkStack(back: 2)) << 8 | UInt16(context.checkStack(back: 1))
       #expect(pushedPC == 0x8003, "PC should be pushed despite interrupt flag")
       
       #expect(context.cpu.registers.status.contains(.interrupt), "Interrupt flag should remain set")
       #expect(context.cpu.clockCycleCount == 4 + 7, "NMI cycles should be added despite interrupt flag")
    }
    
    @Test("NMI priority over IRQ")
    func testNMIPriority() {
        let context = setupCPUState()
        
        // Set up initial state
        context.mmu.write(0xAD, to: 0x8000) // LDA absolute
        context.mmu.write(0x00, to: 0x8001)
        context.mmu.write(0x20, to: 0x8002)
        
        let initialSP = context.cpu.registers.stackPointer
        
        context.cpu.triggerIRQ()
        context.cpu.triggerNMI()
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x10FA, "NMI vector should be used instead of IRQ vector")
        
        let pushedPC = UInt16(context.checkStack(back: 2)) << 8 | UInt16(context.checkStack(back: 1))
        
        #expect(pushedPC == 0x8003, "PC should be pushed by NMI")
        #expect(context.cpu.registers.stackPointer == initialSP - 3, "Stack pointer should reflect single interrupt handling")
        
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.programCounter == 0x10FE, "IRQ should be handled on next instruction")
    }

    // MARK: - Reset Tests
    
    @Test("Reset handling")
    func testReset() {
        let context = setupCPUState()
        
        context.cpu.registers.accumulator = 0xFF
        context.cpu.registers.indexX = 0xFF
        context.cpu.registers.indexY = 0xFF
        context.cpu.registers.stackPointer = 0xFF
        context.cpu.registers.status = Status(rawValue: 0xFF)
        
        context.cpu.push(0x42)
        context.cpu.push(0x43)
        
        let stackPointerBeforeReset = context.cpu.registers.stackPointer
        context.cpu.registers.status.setFlag(.interrupt, to: false)
        
        context.cpu.reset()
        
        #expect(context.cpu.registers.programCounter == 0x10FC,
               "Reset should load PC from reset vector")
        #expect(context.cpu.registers.stackPointer == stackPointerBeforeReset &- 3, "Stack pointer should be decremented by 3")
        #expect(context.cpu.registers.status.contains(.interrupt), "Interrupt flag should be set")
        
        let originalStackValue = context.mmu.read(from: 0x01FF)
        #expect(originalStackValue == 0x42, "Stack contents should not be affected")
        
        #expect(context.cpu.clockCycleCount == 7, "Reset should take 7 cycles")
    }
    
    @Test("Reset takes priority")
    func testResetPriority() {
        let context = setupCPUState()
        
        // Set up initial state
        context.mmu.write(0xEA, to: 0x10FC) // NOP implied
        
        context.cpu.registers.accumulator = 0xFF
        context.cpu.registers.indexX = 0xFF
        context.cpu.registers.indexY = 0xFF
        context.cpu.registers.stackPointer = 0xFF
        context.cpu.registers.status = Status(rawValue: 0xFF)
        
        context.cpu.triggerIRQ()
        context.cpu.triggerNMI()
        
        context.cpu.reset()
        
        #expect(context.cpu.registers.programCounter == 0x10FC, "Reset should load PC from reset vector, not IRQ or NMI vectors")
        #expect(context.cpu.registers.stackPointer == 0xFC, "Reset should decrement SP to 0xFC without pushing to stack")
        #expect(context.cpu.registers.status.contains(.interrupt), "Interrupt flag should be set")
        
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.programCounter != 0x10FA && context.cpu.registers.programCounter != 0x10FE, "IRQ and NMI should be cleared by reset")
    }

    // MARK: - Stack Operation Tests
    
    @Test("Interrupt stack operations")
    func testInterruptStack() {
        let context = setupCPUState()
       
       // Set up initial state with some data already on stack
       context.cpu.push(0x42)
       context.cpu.push(0x43)
       let initialSP = context.cpu.registers.stackPointer
       
       context.mmu.write(0xAD, to: 0x8000) // LDA absolute
       context.mmu.write(0x00, to: 0x8001)
       context.mmu.write(0x20, to: 0x8002)
       
       context.cpu.triggerIRQ()
       context.cpu.executeNextInstruction()
       
       // Verify IRQ stack operations
       let irqStatus = context.checkStack()
       let irqPCLow = context.checkStack(back: 1)
       let irqPCHigh = context.checkStack(back: 2)
       
       #expect(irqStatus & Status.break.rawValue == 0, "IRQ should push status with break clear")
       #expect(UInt16(irqPCHigh) << 8 | UInt16(irqPCLow) == 0x8003,
              "IRQ should push next instruction address")
       #expect(context.cpu.registers.stackPointer == initialSP - 3,
              "IRQ should push 3 bytes to stack")
       
       // Reset test state
       let nmiContext = setupCPUState()
       nmiContext.cpu.push(0x42)
       nmiContext.cpu.push(0x43)
       let nmiInitialSP = nmiContext.cpu.registers.stackPointer
       
       nmiContext.mmu.write(0xAD, to: 0x8000) // LDA absolute
       nmiContext.mmu.write(0x00, to: 0x8001)
       nmiContext.mmu.write(0x20, to: 0x8002)
       
       nmiContext.cpu.triggerNMI()
       nmiContext.cpu.executeNextInstruction()
       
       // Verify NMI stack operations
       let nmiStatus = nmiContext.checkStack()
       let nmiPCLow = nmiContext.checkStack(back: 1)
       let nmiPCHigh = nmiContext.checkStack(back: 2)
       
       #expect(nmiStatus & Status.break.rawValue == 0, "NMI should push status with break clear")
       #expect(UInt16(nmiPCHigh) << 8 | UInt16(nmiPCLow) == 0x8003,
              "NMI should push next instruction address")
       #expect(nmiContext.cpu.registers.stackPointer == nmiInitialSP - 3,
              "NMI should push 3 bytes to stack")
       
       // Verify existing stack data is preserved
       #expect(nmiContext.mmu.read(from: 0x0100 + UInt16(nmiInitialSP + 1)) == 0x43,
              "Existing stack data should be preserved")
       #expect(nmiContext.mmu.read(from: 0x0100 + UInt16(nmiInitialSP + 2)) == 0x42,
              "Existing stack data should be preserved")
    }
    
    @Test("RTI instruction")
    func testRTI() {
       let context = setupCPUState()
       
       let originalStatus = Status([.carry, .zero, .overflow])
       let returnPC: UInt16 = 0x1234
       
       context.cpu.push(UInt8((returnPC >> 8) & 0xFF)) // PC high
       context.cpu.push(UInt8(returnPC & 0xFF)) // PC low
       context.cpu.push(originalStatus.rawValue) // Status
       
       context.mmu.write(0x40, to: 0x8000) // RTI opcode
       let initialSP = context.cpu.registers.stackPointer
       
       context.cpu.executeNextInstruction()
       
       #expect(context.cpu.registers.programCounter == returnPC, "PC should be restored to value from stack")
       #expect(context.cpu.registers.status == originalStatus, "Status register should be restored from stack")
       #expect(context.cpu.registers.stackPointer == initialSP + 3, "Stack pointer should reflect 3 pulls")
       #expect(context.cpu.clockCycleCount == 6, "RTI should take 6 cycles")
    }
}
