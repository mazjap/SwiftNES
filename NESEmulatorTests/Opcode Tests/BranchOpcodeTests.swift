import Testing
@testable import NESEmulator

// Branch Operations (BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS, JMP, JSR, RTS)
@Suite("CPU Branch Operations")
class BranchOpcodeTests: OpcodeTestBase {
    @Test("BCC - Branch not taken (carry set)")
    func testBCC_notTaken() {
        let context = setupRelative(opcode: 0x90, offset: 5, branchTaken: false)
        context.cpu.registers.status.setFlag(.carry, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BCC - Branch taken forward")
    func testBCC_takenForward() {
        let context = setupRelative(opcode: 0x90, offset: 5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        #expect(context.cpu.registers.programCounter == context.initialPC + 7)
    }

    @Test("BCC - Branch taken backward")
    func testBCC_takenBackward() {
        let context = setupRelative(opcode: 0x90, offset: -5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BCC - Branch page boundary forward")
    func testBCC_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0x90, offset: 5, atAddress: 0x08FA, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BCC - Maximum offset values")
    func testBCC_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0x90, offset: 127, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0x90, offset: -128, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BCS - Branch not taken (carry not set)")
    func testBCS_notTaken() {
        let context = setupRelative(opcode: 0xB0, offset: 5, branchTaken: false)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BCS - Branch taken forward")
    func testBCS_takenForward() {
        let context = setupRelative(opcode: 0xB0, offset: 5, branchTaken: true)
        context.cpu.registers.status.setFlag(.carry, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BCS - Branch taken backward")
    func testBCS_takenBackward() {
        let context = setupRelative(opcode: 0xB0, offset: -5, branchTaken: true)
        context.cpu.registers.status.setFlag(.carry, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BCS - Branch page boundary forward")
    func testBCS_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0xB0, offset: 5, atAddress: 0x80F9, branchTaken: true)
        context.cpu.registers.status.setFlag(.carry, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BCS - Maximum offset values")
    func testBCS_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0xB0, offset: 127, branchTaken: true)
        context.cpu.registers.status.setFlag(.carry, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0xB0, offset: -128, branchTaken: true)
        context.cpu.registers.status.setFlag(.carry, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BEQ - Branch not taken (zero not set)")
    func testBEQ_notTaken() {
        let context = setupRelative(opcode: 0xF0, offset: 5, branchTaken: false)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BEQ - Branch taken forward")
    func testBEQ_takenForward() {
        let context = setupRelative(opcode: 0xF0, offset: 5, branchTaken: true)
        context.cpu.registers.status.setFlag(.zero, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BEQ - Branch taken backward")
    func testBEQ_takenBackward() {
        let context = setupRelative(opcode: 0xF0, offset: -5, branchTaken: true)
        context.cpu.registers.status.setFlag(.zero, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BEQ - Branch page boundary")
    func testBEQ_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0xF0, offset: 5, atAddress: 0x80F9, branchTaken: true)
        context.cpu.registers.status.setFlag(.zero, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BEQ - Maximum offset values")
    func testBEQ_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0xF0, offset: 127, branchTaken: true)
        context.cpu.registers.status.setFlag(.zero, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0xF0, offset: -128, branchTaken: true)
        context.cpu.registers.status.setFlag(.zero, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BMI - Branch not taken (negative not set)")
    func testBMI_notTaken() {
        let context = setupRelative(opcode: 0x30, offset: 5, branchTaken: false)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BMI - Branch taken forward")
    func testBMI_takenForward() {
        let context = setupRelative(opcode: 0x30, offset: 5, branchTaken: true)
        context.cpu.registers.status.setFlag(.negative, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BMI - Branch taken backward")
    func testBMI_takenBackward() {
        let context = setupRelative(opcode: 0x30, offset: -5, branchTaken: true)
        context.cpu.registers.status.setFlag(.negative, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BMI - Branch page boundary")
    func testBMI_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0x30, offset: 5, atAddress: 0x80F9, branchTaken: true)
        context.cpu.registers.status.setFlag(.negative, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BMI - Maximum offset values")
    func testBMI_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0x30, offset: 127, branchTaken: true)
        context.cpu.registers.status.setFlag(.negative, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0x30, offset: -128, branchTaken: true)
        context.cpu.registers.status.setFlag(.negative, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BNE - Branch not taken (zero set)")
    func testBNE_notTaken() {
        let context = setupRelative(opcode: 0xD0, offset: 5, branchTaken: false)
        context.cpu.registers.status.setFlag(.zero, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BNE - Branch taken forward")
    func testBNE_takenForward() {
        let context = setupRelative(opcode: 0xD0, offset: 5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BNE - Branch taken backward")
    func testBNE_takenBackward() {
        let context = setupRelative(opcode: 0xD0, offset: -5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BNE - Branch page boundary")
    func testBNE_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0xD0, offset: 5, atAddress: 0x80F9, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BNE - Maximum offset values")
    func testBNE_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0xD0, offset: 127, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0xD0, offset: -128, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BPL - Branch not taken (negative set)")
    func testBPL_notTaken() {
        let context = setupRelative(opcode: 0x10, offset: 5, branchTaken: false)
        context.cpu.registers.status.setFlag(.negative, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BPL - Branch taken forward")
    func testBPL_takenForward() {
        let context = setupRelative(opcode: 0x10, offset: 5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BPL - Branch taken backward")
    func testBPL_takenBackward() {
        let context = setupRelative(opcode: 0x10, offset: -5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BPL - Branch page boundary")
    func testBPL_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0x10, offset: 5, atAddress: 0x80F9, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BPL - Maximum offset values")
    func testBPL_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0x10, offset: 127, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0x10, offset: -128, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BVC - Branch not taken (overflow set)")
    func testBVC_notTaken() {
        let context = setupRelative(opcode: 0x50, offset: 5, branchTaken: false)
        context.cpu.registers.status.setFlag(.overflow, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BVC - Branch taken forward")
    func testBVC_takenForward() {
        let context = setupRelative(opcode: 0x50, offset: 5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BVC - Branch taken backward")
    func testBVC_takenBackward() {
        let context = setupRelative(opcode: 0x50, offset: -5, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BVC - Branch page boundary")
    func testBVC_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0x50, offset: 5, atAddress: 0x80F9, branchTaken: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BVC - Maximum offset values")
    func testBVC_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0x50, offset: 127, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0x50, offset: -128, branchTaken: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BVS - Branch not taken (overflow not set)")
    func testBVS_notTaken() {
        let context = setupRelative(opcode: 0x70, offset: 5, branchTaken: false)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BVS - Branch taken forward")
    func testBVS_takenForward() {
        let context = setupRelative(opcode: 0x70, offset: 5, branchTaken: true)
        context.cpu.registers.status.setFlag(.overflow, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BVS - Branch taken backward")
    func testBVS_takenBackward() {
        let context = setupRelative(opcode: 0x70, offset: -5, branchTaken: true)
        context.cpu.registers.status.setFlag(.overflow, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("BVS - Branch page boundary")
    func testBVS_pageBoundary() {
        // Setup at end of page
        let context = setupRelative(opcode: 0x70, offset: 5, atAddress: 0x80F9, branchTaken: true)
        context.cpu.registers.status.setFlag(.overflow, to: true)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("BVS - Maximum offset values")
    func testBVS_maxOffsets() {
        // Maximum forward branch (+127 | 0x7F)
        var context = setupRelative(opcode: 0x70, offset: 127, branchTaken: true)
        context.cpu.registers.status.setFlag(.overflow, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Maximum backward branch (-128 | 0x80)
        context = setupRelative(opcode: 0x70, offset: -128, branchTaken: true)
        context.cpu.registers.status.setFlag(.overflow, to: true)
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("JMP - Absolute mode normal operation")
    func testJMP_absolute() {
        // Test jumping forward from 0x8000
        var context = setupAbsolute(opcode: 0x4C, absoluteAddress: 0x8765, value: 0x00) // Value doesn't matter for JMP
        context.expected.pcStatus = .absolute(0x8765) // setupAbsolute assumes PC will increment by 3, but JMP replaces PC so we use absolute expected address mode
        context.expected.status = Status.empty // No flags affected
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        // Test jumping backward from 0x8000
        context = setupAbsolute(opcode: 0x4C, absoluteAddress: 0x789A, value: 0x00)
        context.expected.pcStatus = .absolute(0x789A)
        context.expected.status = Status.empty
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("JMP - Indirect mode normal operation")
    func testJMP_indirect() {
        var context = setupIndirect(opcode: 0x6C, indirectAddress: 0x1234, targetAddress: 0x3456)
        context.expected.pcStatus = .absolute(0x3456)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("JMP - Indirect page boundary bug")
    func testJMP_indirectPageBoundary() {
        // Setup pointer at page boundary: $10FF/$1100
        // The bug means high byte is read from $2000 instead of $2100
        var context = setupIndirect(opcode: 0x6C, indirectAddress: 0x10FF, targetAddress: 0x3456)
        
        // Write different value at buggy address
        context.mmu.write(0x56, to: 0x10FF) // Low byte
        context.mmu.write(0x42, to: 0x1000) // High byte will be read from here due to bug
        context.mmu.write(0x34, to: 0x1100) // This high byte should be ignored
        context.expected.pcStatus = .absolute(0x4256)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("JSR/RTS - Basic operation")
    func testJSR_RTS_basic() {
        // Setup JSR at $8000 jumping to $1234
        var context = setupAbsolute(opcode: 0x20, absoluteAddress: 0x1234, value: 0x00) // Value doesn't matter for JSR
        let initialSP = context.cpu.registers.stackPointer
        context.expected.pcStatus = .absolute(0x1234)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        #expect(context.cpu.registers.stackPointer == initialSP - 2, "JSR should push 2 bytes to stack")
        
        // Verify return address on stack (PC - 1)
        let returnAddrHigh = context.mmu.read(from: 0x0100 + UInt16(initialSP))
        let returnAddrLow = context.mmu.read(from: 0x0100 + UInt16(initialSP - 1))
        let returnAddr = UInt16(returnAddrHigh) << 8 | UInt16(returnAddrLow)
        #expect(returnAddr == 0x8002, "JSR should push PC-1 to stack")
        
        // Now execute RTS
        context.mmu.write(0x60, to: 0x1234)  // RTS opcode
        context.cpu.executeNextInstruction()
        
        // Verify RTS behavior
        #expect(context.cpu.registers.programCounter == 0x8003, "RTS should return to address+1")
        #expect(context.cpu.registers.stackPointer == initialSP, "RTS should restore stack pointer")
        #expect(context.cpu.clockCycleCount == 6, "RTS should take 6 cycles")
    }

    @Test("JSR/RTS - Stack operations")
    func testJSR_RTS_stack() {
        // Setup initial stack with some data to ensure we don't corrupt it
        let context = setupAbsolute(opcode: 0x20, absoluteAddress: 0x1234, value: 0x00)
        context.cpu.push(0xAA)
        context.cpu.push(0xBB)
        let initialSP = context.cpu.registers.stackPointer
        
        // Execute JSR
        context.cpu.executeNextInstruction()
        
        // Verify stack wasn't corrupted
        #expect(context.mmu.read(from: 0x0100 + UInt16(initialSP + 2)) == 0xAA, "JSR should not disturb existing stack data")
        #expect(context.mmu.read(from: 0x0100 + UInt16(initialSP + 1)) == 0xBB, "JSR should not disturb existing stack data")
        
        // Setup RTS
        context.mmu.write(0x60, to: 0x1234)
        context.cpu.executeNextInstruction()
        
        // Verify stack was properly restored
        #expect(context.cpu.registers.stackPointer == initialSP, "Stack pointer should be restored")
        #expect(context.mmu.read(from: 0x0100 + UInt16(initialSP + 1)) == 0xBB, "Original stack data should be preserved")
    }

    @Test("JSR/RTS - Nested calls")
    func testJSR_RTS_nested() {
        // Setup first JSR at $8000 -> $1234
        let context = setupAbsolute(opcode: 0x20, absoluteAddress: 0x1234, value: 0x00)
        let initialSP = context.cpu.registers.stackPointer
        
        // Execute first JSR
        context.cpu.executeNextInstruction()
        
        // Setup second JSR at $1234 -> $5678
        context.mmu.write(0x20, to: 0x1234) // JSR opcode
        context.mmu.write(0x78, to: 0x1235) // Target low byte
        context.mmu.write(0x56, to: 0x1236) // Target high byte
        
        // Execute second JSR
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.stackPointer == initialSP - 4, "Nested JSR should push 4 bytes total")
        #expect(context.cpu.registers.programCounter == 0x5678, "Should be at nested subroutine")
        
        // Setup first RTS
        context.mmu.write(0x60, to: 0x5678)
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x1237, "Should return to after second JSR")
        
        // Setup second RTS
        context.mmu.write(0x60, to: 0x1237)
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x8003, "Should return to after first JSR")
        #expect(context.cpu.registers.stackPointer == initialSP, "Stack should be fully restored")
    }

    @Test("JSR/RTS - Page boundary behavior")
    func testJSR_RTS_pageBoundary() {
        // Test JSR from end of page
        let context = setupAbsolute(opcode: 0x20, absoluteAddress: 0x1234, value: 0x00, atAddress: 0x80FF)
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x1234, "JSR should work across page boundary")
        
        // Setup RTS to return across page
        context.mmu.write(0x60, to: 0x1234)
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x8102, "RTS should work across page boundary")
    }
    
    @Test("JSR/RTS - Return address calculation")
    func testJSR_RTS_addressing() {
        // Setup JSR with known return address
        let context = setupAbsolute(opcode: 0x20, absoluteAddress: 0x5678, value: 0x00, atAddress: 0x1234)
        let initialSP = context.cpu.registers.stackPointer
        
        context.cpu.executeNextInstruction()
        
        // Check exact stored addresses
        let storedHigh = context.mmu.read(from: 0x0100 + UInt16(initialSP))
        let storedLow = context.mmu.read(from: 0x0100 + UInt16(initialSP - 1))
        let storedAddr = UInt16(storedHigh) << 8 | UInt16(storedLow)
        
        #expect(storedAddr == 0x1236, "JSR should store PC+2-1 (next instruction - 1)")
        
        // Setup RTS to demonstrate +1 behavior
        context.mmu.write(0x60, to: 0x5678)
        context.cpu.executeNextInstruction()
        
        #expect(context.cpu.registers.programCounter == 0x1237, "RTS should add 1 to pulled address")
    }
}
