import Testing
@testable import SwiftNES

// Status Flag Operations (BRK, CLC, CLD, CLI, CLV, SEC, SED, SEI)
@Suite("CPU Status Flag Operations")
class StatusFlagOpcodeTests: OpcodeTestBase {
    let allStatusFlags = Status(rawValue: 0xFF)
    
    @Test("BRK - Basic operation")
    func testBRK_basic() {
        let context = setupImplied(opcode: 0x00)
        let initialPC = context.cpu.registers.programCounter
        let initialSP = context.cpu.registers.stackPointer
        
        // Setup interrupt vector
        context.mmu.write(0xE7, to: 0xFFFE)  // Low byte
        context.mmu.write(0x1E, to: 0xFFFF)  // High byte
        
        context.cpu.executeNextInstruction()
        
        // Verify interrupt vector was loaded
        #expect(context.cpu.registers.programCounter == 0x1EE7, "Should load interrupt vector")
        
        // Verify stack contents (in reverse order of pushing)
        let statusOnStack = context.mmu.read(from: 0x0100 + UInt16(initialSP - 2))
        let pcLow = context.mmu.read(from: 0x0100 + UInt16(initialSP - 1))
        let pcHigh = context.mmu.read(from: 0x0100 + UInt16(initialSP))
        
        // Check PC on stack is original PC + 2
        let storedPC = UInt16(pcHigh) << 8 | UInt16(pcLow)
        #expect(storedPC == initialPC + 2, "Should store PC+2 on stack")
        
        // Check status byte has break flag set
        #expect(statusOnStack & Status.break.rawValue != 0, "Break flag should be set in stored status")
        
        // Verify current processor status
        #expect(context.cpu.registers.status.contains(.interrupt), "Interrupt disable should be set")
        #expect(!context.cpu.registers.status.contains(.break), "Break flag should not be set in current status")
        
        // Verify stack pointer
        #expect(context.cpu.registers.stackPointer == initialSP - 3, "Should push 3 bytes to stack")
        
        // Verify cycles
        #expect(context.cpu.clockCycleCount == 7, "BRK should take 7 cycles")
    }

    @Test("BRK - RTI restoration")
    func testBRK_RTI() {
        let context = setupImplied(opcode: 0x00)
        let initialPC = context.cpu.registers.programCounter
        
        // Setup interrupt vector
        context.mmu.write(0xE7, to: 0xFFFE)
        context.mmu.write(0x1E, to: 0xFFFF)
        
        // Put RTI at interrupt handler
        context.mmu.write(0x40, to: 0x1EE7)  // RTI opcode
        
        // Execute BRK
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.programCounter == 0x1EE7, "Should jump to interrupt handler")
        
        // Execute RTI
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.programCounter == initialPC + 2, "Should return to instruction after BRK")
        #expect(!context.cpu.registers.status.contains(.break), "Break flag should not be set after RTI")
        #expect(!context.cpu.registers.status.contains(.interrupt), "Interrupt flag should be restored")
    }

    @Test("BRK - With flags set")
    func testBRK_flags() {
        let context = setupImplied(opcode: 0x00)
        
        // Set some flags before BRK
        context.cpu.registers.status = Status([.carry, .zero, .overflow])
        
        // Setup interrupt vector
        context.mmu.write(0xE7, to: 0xFFFE)
        context.mmu.write(0x1E, to: 0xFFFF)
        
        context.cpu.executeNextInstruction()
        
        // Check that flags were preserved in stack
        let statusOnStack = context.mmu.read(from: 0x0100 + UInt16(context.cpu.registers.stackPointer + 1))
        let expectedFlags = Status([.carry, .zero, .overflow, .break]).rawValue
        #expect(statusOnStack == expectedFlags, "Stored status should preserve flags and set break")
        
        // Current status should have interrupt set but not break
        let expectedCurrentFlags = Status([.carry, .zero, .overflow, .interrupt])
        #expect(context.cpu.registers.status == expectedCurrentFlags,
               "Current status should preserve flags, set interrupt, not break")
    }
    
    @Test("CLC - implied mode")
    func CLC_implied() {
        var context = setupImplied(opcode: 0x18)
        
        // Set carry before clearing
        context.cpu.registers.status = Status.carry
        context.expected.status = Status.empty
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("CLD - implied mode")
    func CLD_implied() {
        var context = setupImplied(opcode: 0xD8)
        
        // Set decimal before clearing
        context.cpu.registers.status = Status.decimal
        context.expected.status = Status.empty
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("CLI - implied mode")
    func CLI_implied() {
        var context = setupImplied(opcode: 0x58)
        
        // Set interrupt before clearing
        context.cpu.registers.status = Status.interrupt
        context.expected.status = Status.empty
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("CLV - implied mode")
    func CLV_implied() {
        var context = setupImplied(opcode: 0xB8)
        
        // Set overflow before clearing
        context.cpu.registers.status = Status.overflow
        context.expected.status = Status.empty
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("SEC - implied mode")
    func SEC_implied() {
        var context = setupImplied(opcode: 0x38)
        
        context.expected.status = Status.carry
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("SED - implied mode")
    func SED_implied() {
        var context = setupImplied(opcode: 0xF8)
        
        context.expected.status = Status.decimal
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }

    @Test("SEI - implied mode")
    func SEI_implied() {
        var context = setupImplied(opcode: 0x78)
        
        context.expected.status = Status.interrupt
        
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
    }
    
    @Test("Flag operations - Multiple flags", arguments: [
        (UInt8(0x18), UInt8(0x38), Status.carry),
        (UInt8(0xD8), UInt8(0xF8), Status.decimal),
        (UInt8(0x58), UInt8(0x78), Status.interrupt)
    ])
    func testFlagOperations_multipleFlags(clearOpcode: UInt8, setOpcode: UInt8, flag: Status) {
        // Verify clear operations only affect their specific flag
        var context = setupImplied(opcode: clearOpcode)
        context.cpu.registers.status = allStatusFlags
        context.expected.status = Status(rawValue: ~flag.rawValue)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Verify set operations only affect their specific flag
        context = setupImplied(opcode: setOpcode)
        context.cpu.registers.status = Status(rawValue: ~flag.rawValue)
        context.expected.status = allStatusFlags
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
}
