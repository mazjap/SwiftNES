import Testing
@testable import NESEmulator

// Shift & Rotate (ASL, LSR, ROL, ROR)
@Suite("CPU Shift and Rotate Operations")
class ShiftRotateOpcodeTests: OpcodeTestBase {
    @Test("ASL - implied mode")
    func ASL_implied() {
        var context = setupImplied(opcode: 0x0A)
        context.cpu.registers.accumulator = 0b01111111
        context.expected.a = 0b11111110
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("ASL - zeropage mode")
    func ASL_zeropage() {
        let context = setupZeroPage(opcode: 0x06, zeroPageAddress: 0xFA, value: 0b10000000)
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        #expect(context.mmu.read(from: 0xFA) == 0b00000000)
    }

    @Test("ASL - zeropage,x mode")
    func ASL_zeropageX() {
        let context = setupZeroPageX(opcode: 0x16, zeroPageAddress: 0x10, xOffset: 0x10, value: 0b01010101)
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        #expect(context.mmu.read(from: 0x20) == 0b10101010)
    }

    @Test("ASL - absolute mode")
    func ASL_absolute() {
        let context = setupAbsolute(opcode: 0x0E, absoluteAddress: 0x1234, value: 0b00111111)
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        #expect(context.mmu.read(from: 0x1234) == 0b01111110)
    }

    @Test("ASL - absolute,x mode")
    func ASL_absoluteX() {
        let contextNoCross = setupAbsoluteX(opcode: 0x1E, absoluteAddress: 0x12EF, xOffset: 0x01, value: 0b11000000)
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        let contextWithCross = setupAbsoluteX(opcode: 0x1E, absoluteAddress: 0x12FF, xOffset: 0x01, value: 0b11000000)
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x12F0) == 0b10000000)
        #expect(contextWithCross.mmu.read(from: 0x1300) == 0b10000000)
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount) // ASL uses same amount of cycles, even if page boundary is crossed
    }
    
    @Test("ASL - Flag behavior")
    func testASL_flags() {
        func testASLFlags(value: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0x0A)
            context.cpu.registers.accumulator = value
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.accumulator, context.cpu.registers.status)
        }
        
        // Test carry flag gets set from bit 7
        let test1 = testASLFlags(value: 0b10000000)
        #expect(test1.result == 0b00000000, "Shifting 0x80 left should give 0")
        #expect(test1.flags == Status([.carry, .zero]),
               "Shifting out a 1 should set carry, and zero result should set zero")
        
        // Test negative flag gets set when result has bit 7 set
        let test2 = testASLFlags(value: 0b01000000)
        #expect(test2.result == 0b10000000, "Shifting 0x40 left should give 0x80")
        #expect(test2.flags == Status.negative,
               "Result with bit 7 set should set negative flag")
        
        // Test no flags when result is positive non-zero
        let test3 = testASLFlags(value: 0b00100000)
        #expect(test3.result == 0b01000000, "Shifting 0x20 left should give 0x40")
        #expect(test3.flags == Status.empty,
               "Positive non-zero result should set no flags")
        
        // Test zero flag when shifting all zeros
        let test4 = testASLFlags(value: 0b00000000)
        #expect(test4.result == 0b00000000, "Shifting 0 left should give 0")
        #expect(test4.flags == Status.zero,
               "Zero result should set zero flag")
        
        // Test preserving overflow flag (it shouldn't be affected)
        let context = setupImplied(opcode: 0x0A)
        context.cpu.registers.accumulator = 0b00000000
        context.cpu.registers.status = Status.overflow
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.overflow, .zero]),
               "ASL should preserve overflow flag")
    }
    
    @Test("LSR - implied mode")
    func LSR_implied() {
        var context = setupImplied(opcode: 0x4A)
        context.cpu.registers.accumulator = 0b11111111
        context.expected.a = 0b01111111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("LSR - zeropage mode")
    func LSR_zeropage() {
        let context = setupZeroPage(opcode: 0x46, zeroPageAddress: 0x71, value: 0b11111110)
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        #expect(context.mmu.read(from: 0x71) == 0b01111111)
    }

    @Test("LSR - zeropage,x mode")
    func LSR_zeropageX() {
        let context = setupZeroPageX(opcode: 0x56, zeroPageAddress: 0x60, xOffset: 0x10, value: 0b00000001)
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        #expect(context.mmu.read(from: 0x70) == 0)
    }

    @Test("LSR - absolute mode")
    func LSR_absolute() {
        let context = setupAbsolute(opcode: 0x4E, absoluteAddress: 0x1024, value: 0b10000000)
        context.cpu.executeNextInstruction()
        
        verifyCPUState(context: context)
        #expect(context.mmu.read(from: 0x1024) == 0b01000000)
    }

    @Test("LSR - absolute,x mode")
    func LSR_absoluteX() {
        let contextNoCross = setupAbsoluteX(opcode: 0x5E, absoluteAddress: 0x0F55, xOffset: 0xAA, value: 0b10110100)
        contextNoCross.cpu.executeNextInstruction()
        
        verifyCPUState(context: contextNoCross)
        
        
        let contextWithCross = setupAbsoluteX(opcode: 0x5E, absoluteAddress: 0x0F55, xOffset: 0xAB, value: 0b10110100)
        contextWithCross.cpu.executeNextInstruction()
        
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0FFF) == 0b01011010)
        #expect(contextWithCross.mmu.read(from: 0x1000) == 0b01011010)
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount) // LSR uses same amount of cycles, even if page boundary is crossed
    }
    
    @Test("LSR - Flag behavior")
    func testLSR_flags() {
        func testLSRFlags(value: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0x4A)
            context.cpu.registers.accumulator = value
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.accumulator, context.cpu.registers.status)
        }
        
        // Test carry flag gets set from bit 0
        let test1 = testLSRFlags(value: 0b00000001)
        #expect(test1.result == 0b00000000, "Shifting 1 right should give 0")
        #expect(test1.flags == Status([.carry, .zero]),
               "Shifting out a 1 should set carry, and zero result should set zero")
        
        // Test no flags set for positive non-zero result
        let test2 = testLSRFlags(value: 0b11000000)
        #expect(test2.result == 0b01100000, "Shifting 0xC0 right should give 0x60")
        #expect(test2.flags == Status.empty,
               "Positive non-zero result should set no flags")
        
        // Test zero flag when shifting 0
        let test3 = testLSRFlags(value: 0b00000000)
        #expect(test3.result == 0b00000000, "Shifting 0 right should give 0")
        #expect(test3.flags == Status.zero,
               "Zero result should set zero flag")
        
        // Test negative flag is never set (bit 7 is always 0 after shift)
        let test4 = testLSRFlags(value: 0b10000000)
        #expect(test4.result == 0b01000000, "Shifting 0x80 right should give 0x40")
        #expect(test4.flags == Status.empty,
               "Result can never be negative since bit 7 is always cleared")
        
        // Test preserving overflow flag (it shouldn't be affected)
        let context = setupImplied(opcode: 0x4A)
        context.cpu.registers.accumulator = 0b00000000
        context.cpu.registers.status = Status.overflow
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.overflow, .zero]),
               "LSR should preserve overflow flag")
    }
    
    @Test("ROL - implied mode")
    func ROL_implied() {
        var context = setupImplied(opcode: 0x2A)
        context.cpu.registers.accumulator = 0b10000000
        context.expected.a = 0
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("ROL - zeropage mode")
    func ROL_zeropage() {
        let context = setupZeroPage(opcode: 0x26, zeroPageAddress: 0xDF, value: 0b01000000)
        context.cpu.registers.status = Status.carry
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0xDF) == 0b10000001)
    }
    
    @Test("ROL - zeropage,x mode")
    func ROL_zeropageX() {
        let context = setupZeroPageX(opcode: 0x36, zeroPageAddress: 0x4A, xOffset: 0x06, value: 0b00000111)
        context.cpu.registers.status = Status.carry
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x50) == 0b00001111)
    }
    
    @Test("ROL - absolute mode")
    func ROL_absolute() {
        let context = setupAbsolute(opcode: 0x2E, absoluteAddress: 0x0100, value: 0b11000101)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0100) == 0b10001010)
    }
    
    @Test("ROL - absolute,x mode")
    func ROL_absoluteX() {
        let context = setupAbsoluteX(opcode: 0x3E, absoluteAddress: 0x1234, xOffset: 0x10, value: 0b01010101)
        context.cpu.registers.status = Status.carry
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1244) == 0b10101011)
    }
    
    @Test("ROL - absolute,x mode")
    func ROL_absoluteX_pageCross() {
        let contextNoCross = setupAbsoluteX(opcode: 0x3E, absoluteAddress: 0x1300, xOffset: 0x01, value: 0b00000001)
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        let contextWithCross = setupAbsoluteX(opcode: 0x3E, absoluteAddress: 0x12FF, xOffset: 0x02, value: 0b00000001)
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x1301) == 0b00000010)
        #expect(contextWithCross.mmu.read(from: 0x1301) == 0b00000010)
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount) // ROL uses same amount of cycles, even if page boundary is crossed
    }
    
    @Test("ROL - Flag behavior")
    func testROL_flags() {
        func testROLFlags(value: UInt8, carryIn: Bool = false) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0x2A)
            context.cpu.registers.accumulator = value
            context.cpu.registers.status.setFlag(.carry, to: carryIn)
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.accumulator, context.cpu.registers.status)
        }
        
        // Test carry out, with no carry in
        let test1 = testROLFlags(value: 0b10000000)
        #expect(test1.result == 0b00000000, "ROL 0x80 should give 0 with carry out")
        #expect(test1.flags == Status([.carry, .zero]),
               "Rotating out bit 7 should set carry, zero result sets zero")
        
        // Test carry in affects result
        let test2 = testROLFlags(value: 0b01000000, carryIn: true)
        #expect(test2.result == 0b10000001, "ROL 0x40 with carry should give 0x81")
        #expect(test2.flags == Status.negative,
               "Result with bit 7 set should set negative flag")
        
        // Test no flags with normal rotation (no carry in/out)
        let test3 = testROLFlags(value: 0b00100000)
        #expect(test3.result == 0b01000000, "ROL 0x20 should give 0x40")
        #expect(test3.flags == Status.empty,
               "Positive non-zero result should set no flags")
        
        // Test rotating zero with carry in
        let test4 = testROLFlags(value: 0b00000000, carryIn: true)
        #expect(test4.result == 0b00000001, "ROL 0 with carry should give 1")
        #expect(test4.flags == Status.empty,
               "Small positive result should set no flags")
        
        // Test preserving overflow flag (it shouldn't be affected)
        let context = setupImplied(opcode: 0x2A)
        context.cpu.registers.accumulator = 0b00000000
        context.cpu.registers.status = Status([.overflow, .carry])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.overflow,
               "ROL should preserve overflow flag")
    }
    
    @Test("ROR - implied mode")
    func ROR_implied() {
        var context = setupImplied(opcode: 0x6A)
        context.cpu.registers.accumulator = 0b00000001
        context.expected.a = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("ROR - zeropage mode")
    func ROR_zeropage() {
        let context = setupZeroPage(opcode: 0x66, zeroPageAddress: 0x42, value: 0b00000010)
        context.cpu.registers.status = Status.carry
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x42) == 0b10000001, "Carry-in should set top bit")
    }
    
    @Test("ROR - zeropage,x mode")
    func ROR_zeropageX() {
        let context = setupZeroPageX(opcode: 0x76, zeroPageAddress: 0x10, xOffset: 0x10, value: 0b11111111)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x20) == 0b01111111, "No carry-in should clear top bit")
    }

    @Test("ROR - absolute mode")
    func ROR_absolute() {
        let context = setupAbsolute(opcode: 0x6E, absoluteAddress: 0x0234, value: 0b00000000)
        context.cpu.registers.status = Status.carry
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0234) == 0b10000000)
    }

    @Test("ROR - absolute,x mode")
    func ROR_absoluteX() {
        let contextNoCross = setupAbsoluteX(opcode: 0x7E, absoluteAddress: 0x0432, xOffset: 0x23, value: 0b10101010)
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        let contextWithCross = setupAbsoluteX(opcode: 0x7E, absoluteAddress: 0x0432, xOffset: 0xCE, value: 0b10101010)
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0455) == 0b01010101)
        #expect(contextWithCross.mmu.read(from: 0x0500) == 0b01010101)
        
        // ROR uses same amount of cycles, even if page boundary is crossed
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount)
    }
    
    @Test("ROR - Flag behavior")
    func testROR_flags() {
        func testRORFlags(value: UInt8, initialCarry: Bool = false) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0x6A)
            context.cpu.registers.accumulator = value
            context.cpu.registers.status.setFlag(.carry, to: initialCarry)
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.accumulator, context.cpu.registers.status)
        }
        
        // Test carry out from bit 0
        let test1 = testRORFlags(value: 0b00000001)
        #expect(test1.result == 0b00000000, "ROR 0x01 should give 0x00")
        #expect(test1.flags == Status([.carry, .zero]),
               "Rotating out 1 should set carry, zero result sets zero")
        
        // Test carry in sets bit 7
        let test2 = testRORFlags(value: 0b00000000, initialCarry: true)
        #expect(test2.result == 0b10000000, "ROR 0x00 with carry should give 0x80")
        #expect(test2.flags == Status.negative,
               "Carry rotated to bit 7 should set negative flag")
        
        // Test both carry in and carry out
        let test3 = testRORFlags(value: 0b00000001, initialCarry: true)
        #expect(test3.result == 0b10000000, "ROR 0x01 with carry should give 0x80")
        #expect(test3.flags == Status([.carry, .negative]),
               "Should set both carry (from bit 0) and negative (from carry in)")
        
        // Test no flags when result is positive non-zero
        let test4 = testRORFlags(value: 0b00000100)
        #expect(test4.result == 0b00000010, "ROR 0x04 should give 0x02")
        #expect(test4.flags == Status.empty,
               "Positive non-zero result should set no flags")
        
        // Test preserving overflow flag (it shouldn't be affected)
        let context = setupImplied(opcode: 0x6A)
        context.cpu.registers.accumulator = 0b00000001
        context.cpu.registers.status = Status([.overflow, .carry])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.negative, .overflow, .carry]),
               "ROR should preserve overflow flag")
    }
}
