import Testing
import NESEmulator

// Logic Operations (AND, BIT, CMP, CPX, CPY, EOR, ORA)
@Suite("CPU Logic Operations")
class LogicOpcodeTests: OpcodeTestBase {
    @Test("AND - immediate mode")
    func testAND_immediate() {
        var context = setupImmediate(opcode: 0x29, value: 0b11111110)
        context.cpu.registers.accumulator = 0b00000001
        context.expected.a = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0b11111110, "Memory should remain unchanged")
    }
    
    @Test("AND - zeropage mode")
    func testAND_zeropage() {
        var context = setupZeroPage(opcode: 0x25, zeroPageAddress: 0x20, value: 0b10101010)
        context.cpu.registers.accumulator = 0b10000110
        context.expected.a = 0b10000010
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x20) == 0b10101010, "Memory should remain unchanged")
    }
    
    @Test("AND - zeropage,x mode")
    func testAND_zeropageX() {
        var context = setupZeroPageX(opcode: 0x35, zeroPageAddress: 0xA0, xOffset: 0x20, value: 0b11100111)
        context.cpu.registers.accumulator = 0b00111100
        context.expected.a = 0b00100100
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0xC0) == 0b11100111, "Memory should remain unchanged")
    }
    
    @Test("AND - absolute mode")
    func testAND_absolute() {
        var context = setupAbsolute(opcode: 0x2D, absoluteAddress: 0x1111, value: 0b11110000)
        context.cpu.registers.accumulator = 0b11111111
        context.expected.a = 0b11110000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1111) == 0b11110000, "Memory should remain unchanged")
    }
    
    @Test("AND - absolute,x mode")
    func testAND_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0x3D, absoluteAddress: 0x1000, xOffset: 0x01, value: 0b10001000)
        contextNoCross.cpu.registers.accumulator = 0b00000000
        contextNoCross.expected.a = 0b00000000
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0x3D, absoluteAddress: 0x10FF, xOffset: 0x01, value: 0b10001000)
        contextWithCross.cpu.registers.accumulator = 0b00000000
        contextWithCross.expected.a = 0b00000000
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x1001) == 0b10001000, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x1100) == 0b10001000, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("AND - absolute,y mode")
    func testAND_absoluteY() {
        var contextNoCross = setupAbsoluteY(opcode: 0x39, absoluteAddress: 0x1100, yOffset: 0x22, value: 0b11111111)
        contextNoCross.cpu.registers.accumulator = 0b11111111
        contextNoCross.expected.a = 0b11111111
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteY(opcode: 0x39, absoluteAddress: 0x11FF, yOffset: 0x22, value: 0b11111111)
        contextWithCross.cpu.registers.accumulator = 0b11111111
        contextWithCross.expected.a = 0b11111111
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x1122) == 0b11111111, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x1221) == 0b11111111, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("AND - (d,x) mode")
    func testAND_indexedIndirect() {
        var context = setupIndexedIndirect(opcode: 0x21, zeroPageAddress: 0x16, xOffset: 0x75, targetAddress: 0x1100, value: 0b11110000)
        context.cpu.registers.accumulator = 0b00001111
        context.expected.a = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1100) == 0b11110000, "Memory should remain unchanged")
    }
    
    @Test("AND - (d),y mode")
    func testAND_indirectIndexed() {
        var contextNoCross = setupIndirectIndexed(opcode: 0x31, zeroPageAddress: 0x02, yOffset: 0x0D, targetAddress: 0x0987, value: 0b00011000)
        contextNoCross.cpu.registers.accumulator = 0b11010101
        contextNoCross.expected.a = 0b00010000
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupIndirectIndexed(opcode: 0x31, zeroPageAddress: 0x02, yOffset: 0x0D, targetAddress: 0x09FF, value: 0b00011000)
        contextWithCross.cpu.registers.accumulator = 0b11010101
        contextWithCross.expected.a = 0b00010000
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0994) == 0b00011000, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0A0C) == 0b00011000, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("AND - Flag behavior")
    func testAND_flags() {
        func testANDFlags(a: UInt8, m: UInt8) -> Status {
            let context = setupImmediate(opcode: 0x29, value: m)
            context.cpu.registers.accumulator = a
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // Test zero flag
        let test1 = testANDFlags(a: 0xFF, m: 0x00)
        #expect(test1 == .zero, "Zero flag should be set when result is 0")
        
        // Test negative flag
        let test2 = testANDFlags(a: 0xFF, m: 0x80)
        #expect(test2 == .negative, "Negative flag should be set when bit 7 is set")
        
        // Test no flags
        let test3 = testANDFlags(a: 0x01, m: 0x01)
        #expect(test3 == .empty, "No flags should be set for positive non-zero result")
    }
    
    @Test("BIT - zeropage mode")
    func testBIT_zeropage() {
        var context = setupZeroPage(opcode: 0x24, zeroPageAddress: 0x20, value: 0b11000000)
        context.cpu.registers.accumulator = 0b00000001
        context.expected.a = 0b00000001 // Accumulator should remain unchanged
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x20) == 0b11000000, "Memory should remain unchanged")
    }

    @Test("BIT - absolute mode")
    func testBIT_absolute() {
        var context = setupAbsolute(opcode: 0x2C, absoluteAddress: 0x1234, value: 0b01000000)
        context.cpu.registers.accumulator = 0b01000000
        context.expected.a = 0b01000000 // Accumulator should remain unchanged
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1234) == 0b01000000, "Memory should remain unchanged")
    }

    @Test("BIT - Flag behavior")
    func testBIT_flags() {
        // Helper to run BIT and return flags
        func testBITFlags(a: UInt8, m: UInt8) -> Status {
            let context = setupZeroPage(opcode: 0x24, zeroPageAddress: 0x20, value: m)
            context.cpu.registers.accumulator = a
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // Test 1: All flags set (bits 7,6 set in memory, AND result zero)
        let test1 = testBITFlags(a: 0x00, m: 0xC0)  // Memory: 0b11000000, A: 0b00000000
        #expect(test1 == Status([.negative, .overflow, .zero]),
               "N,V from memory bits 7,6; Z from zero AND result")
        
        // Test 2: N,V clear, Z set (bits 7,6 clear, AND result zero)
        let test2 = testBITFlags(a: 0x01, m: 0x02)  // Memory: 0b00000010, A: 0b00000001
        #expect(test2 == Status.zero,
               "N,V clear from memory, Z set from zero AND result")
        
        // Test 3: Only N set (bit 7 set, non-zero AND result)
        let test3 = testBITFlags(a: 0x80, m: 0x80)  // Memory: 0b10000000, A: 0b10000000
        #expect(test3 == Status.negative,
               "N set from memory bit 7, non-zero AND result")
        
        // Test 4: Only V set (bit 6 set, non-zero AND result)
        let test4 = testBITFlags(a: 0x40, m: 0x40)  // Memory: 0b01000000, A: 0b01000000
        #expect(test4 == Status.overflow,
               "V set from memory bit 6, non-zero AND result")
        
        // Test 5: Verify accumulator not modified
        var context = setupZeroPage(opcode: 0x24, zeroPageAddress: 0x20, value: 0xFF)
        context.cpu.registers.accumulator = 0x42
        context.expected.status = Status([.negative, .overflow])
        context.expected.a = 0x42  // Accumulator should remain unchanged
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("CMP - immediate mode")
    func testCMP_immediate() {
        var context = setupImmediate(opcode: 0xC9, value: 0b10000000)
        context.cpu.registers.accumulator = 0b10000000
        context.expected.a = 0b10000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0b10000000, "Memory should remain unchanged")
    }
    
    @Test("CMP - zeropage mode")
    func testCMP_zeropage() {
        var context = setupZeroPage(opcode: 0xC5, zeroPageAddress: 0x77, value: 0b00000001)
        context.cpu.registers.accumulator = 0b00000001
        context.expected.a = 0b00000001
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x77) == 0b00000001, "Memory should remain unchanged")
    }
    
    @Test("CMP - zeropage,x mode")
    func testCMP_zeropageX() {
        var context = setupZeroPageX(opcode: 0xD5, zeroPageAddress: 0x7F, xOffset: 0x01, value: 0b00000001)
        context.cpu.registers.accumulator = 0b00001111
        context.expected.a = 0b00001111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x80) == 0b00000001, "Memory should remain unchanged")
    }
    
    @Test("CMP - absolute mode")
    func testCMP_absolute() {
        var context = setupAbsolute(opcode: 0xCD, absoluteAddress: 0x1551, value: 0b11111111)
        context.cpu.registers.accumulator = 0b00000000
        context.expected.a = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1551) == 0b11111111, "Memory should remain unchanged")
    }
    
    @Test("CMP - absolute,x mode")
    func testCMP_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0xDD, absoluteAddress: 0x1000, xOffset: 0xFF, value: 0b10101010)
        contextNoCross.cpu.registers.accumulator = 0b10000000
        contextNoCross.expected.a = 0b10000000
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0xDD, absoluteAddress: 0x1001, xOffset: 0xFF, value: 0b10101010)
        contextWithCross.cpu.registers.accumulator = 0b10000000
        contextWithCross.expected.a = 0b10000000
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x10FF) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x1100) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("CMP - absolute,y mode")
    func testCMP_absoluteY() {
        var contextNoCross = setupAbsoluteY(opcode: 0xD9, absoluteAddress: 0x07ED, yOffset: 0x12, value: 0b00000000)
        contextNoCross.cpu.registers.accumulator = 0b00000000
        contextNoCross.expected.a = 0b00000000
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteY(opcode: 0xD9, absoluteAddress: 0x07ED, yOffset: 0x13, value: 0b00000000)
        contextWithCross.cpu.registers.accumulator = 0b00000000
        contextWithCross.expected.a = 0b00000000
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x07ED) == 0b00000000, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0800) == 0b00000000, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("CMP - (d,x) mode")
    func testCMP_indexedIndirect() {
        var context = setupIndexedIndirect(opcode: 0xC1, zeroPageAddress: 0x52, xOffset: 0x55, targetAddress: 0x0567, value: 0b10101010)
        context.cpu.registers.accumulator = 0b00110011
        context.expected.a = 0b00110011
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0567) == 0b10101010, "Memory should remain unchanged")
    }
    
    @Test("CMP - (d),y mode")
    func testCMP_indirectIndexed() {
        var contextNoCross = setupIndirectIndexed(opcode: 0xD1, zeroPageAddress: 0x10, yOffset: 0x99, targetAddress: 0x0900, value: 0b00000001)
        contextNoCross.cpu.registers.accumulator = 0b00000010
        contextNoCross.expected.a = 0b00000010
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupIndirectIndexed(opcode: 0xD1, zeroPageAddress: 0x10, yOffset: 0x99, targetAddress: 0x0967, value: 0b00000001)
        contextWithCross.cpu.registers.accumulator = 0b00000010
        contextWithCross.expected.status = Status.carry
        contextWithCross.expected.a = 0b00000010
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0999) == 0b00000001, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0A00) == 0b00000001, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("CMP - Flag behavior")
    func testCMP_flags() {
        // TODO: - Test that only NZC flags are affected
        func testCMPFlags(a: UInt8, m: UInt8) -> Status {
            let context = setupImmediate(opcode: 0xC9, value: m)
            context.cpu.registers.accumulator = a
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // A = M
        let test1 = testCMPFlags(a: 0x42, m: 0x42)
        #expect(test1 == Status([.carry, .zero]),
               "Equal values set carry and zero")
        
        // A > M
        let test2 = testCMPFlags(a: 0x42, m: 0x40)
        #expect(test2 == Status.carry,
               "A > M sets carry only")
        
        // A < M
        let test3 = testCMPFlags(a: 0x40, m: 0x42)
        #expect(test3 == Status.negative,
               "A < M sets negative only")

        // A = 0, M = 0xFF
        let test4 = testCMPFlags(a: 0x00, m: 0xFF)
        #expect(test4 == Status.empty,
               "Large subtraction wraps around to positive, expected no set flags")

        // A = 0xFF, M = 0x01
        let test5 = testCMPFlags(a: 0xFF, m: 0x01)
        #expect(test5 == Status([.carry, .negative]),
               "Both carry and negative should be set")
    }
    
    @Test("CPX - immediate mode")
    func testCPX_immediate() {
        var context = setupImmediate(opcode: 0xE0, value: 0b10000000)
        context.cpu.registers.indexX = 0b10000000
        context.expected.x = 0b10000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0b10000000, "Memory should remain unchanged")
    }
    
    @Test("CPX - zeropage mode")
    func testCPX_zeropage() {
        var context = setupZeroPage(opcode: 0xE4, zeroPageAddress: 0x77, value: 0b10101010)
        context.cpu.registers.indexX = 0b10000000
        context.expected.x = 0b10000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x77) == 0b10101010, "Memory should remain unchanged")
    }
    
    @Test("CPX - absolute mode")
    func testCPX_absolute() {
        var context = setupAbsolute(opcode: 0xEC, absoluteAddress: 0x1551, value: 0b11111111)
        context.cpu.registers.indexX = 0b00000000
        context.expected.x = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1551) == 0b11111111, "Memory should remain unchanged")
    }
    
    @Test("CPX - Flag behavior")
    func testCPX_flags() {
        func testCPXFlags(x: UInt8, m: UInt8) -> Status {
            let context = setupImmediate(opcode: 0xE0, value: m)
            context.cpu.registers.indexX = x
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // X = M
        let test1 = testCPXFlags(x: 0x42, m: 0x42)
        #expect(test1 == Status([.carry, .zero]),
               "Equal values set carry and zero")
        
        // X > M
        let test2 = testCPXFlags(x: 0x42, m: 0x40)
        #expect(test2 == Status.carry,
               "X > M sets carry only")
        
        // X < M
        let test3 = testCPXFlags(x: 0x40, m: 0x42)
        #expect(test3 == Status.negative,
               "X < M sets negative only")
        
        // X = 0, M = 0xFF
        let test4 = testCPXFlags(x: 0x00, m: 0xFF)
        #expect(test4 == Status.empty,
               "Large subtraction wraps around to positive, expected all flags cleared")

        // X = 0xFF, M = 0x01
        let test5 = testCPXFlags(x: 0xFF, m: 0x01)
        #expect(test5 == Status([.carry, .negative]),
               "Both carry and negative should be set")
    }
    
    @Test("CPY - immediate mode")
    func testCPY_immediate() {
        var context = setupImmediate(opcode: 0xC0, value: 0b10000000)
        context.cpu.registers.indexY = 0b10000000
        context.expected.y = 0b10000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0b10000000, "Memory should remain unchanged")
    }
    
    @Test("CPY - zeropage mode")
    func testCPY_zeropage() {
        var context = setupZeroPage(opcode: 0xC4, zeroPageAddress: 0x77, value: 0b10101010)
        context.cpu.registers.indexY = 0b10000000
        context.expected.y = 0b10000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x77) == 0b10101010, "Memory should remain unchanged")
    }
    
    @Test("CPY - absolute mode")
    func testCPY_absolute() {
        var context = setupAbsolute(opcode: 0xCC, absoluteAddress: 0x1551, value: 0b11111111)
        context.cpu.registers.indexY = 0b00000000
        context.expected.y = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1551) == 0b11111111, "Memory should remain unchanged")
    }
    
    @Test("CPY - Flag behavior")
    func testCPY_flags() {
        func testCPYFlags(y: UInt8, m: UInt8) -> Status {
            let context = setupImmediate(opcode: 0xC0, value: m)
            context.cpu.registers.indexY = y
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // Y = M
        let test1 = testCPYFlags(y: 0x42, m: 0x42)
        #expect(test1 == Status([.carry, .zero]),
               "Equal values set carry and zero")
        
        // Y > M
        let test2 = testCPYFlags(y: 0x42, m: 0x40)
        #expect(test2 == Status.carry,
               "Y > M sets carry only")
        
        // Y < M
        let test3 = testCPYFlags(y: 0x40, m: 0x42)
        #expect(test3 == Status.negative,
               "Y < M sets negative only")
        
        // Y = 0, M = 0xFF
        let test4 = testCPYFlags(y: 0x00, m: 0xFF)
        #expect(test4 == Status.empty,
               "Large subtraction wraps around to positive, expected all flags to be cleared")

        // Y = 0xFF, M = 0x01
        let test5 = testCPYFlags(y: 0xFF, m: 0x01)
        #expect(test5 == Status([.carry, .negative]),
               "Both carry and negative should be set")
    }
    
    @Test("EOR - immediate mode")
    func testEOR_immediate() {
        var context = setupImmediate(opcode: 0x49, value: 0b11111111)
        context.cpu.registers.accumulator = 0b11111111
        context.expected.a = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0b11111111, "Memory should remain unchanged")
    }

    @Test("EOR - zeropage mode")
    func testEOR_zeropage() {
        var context = setupZeroPage(opcode: 0x45, zeroPageAddress: 0x21, value: 0b11111111)
        context.cpu.registers.accumulator = 0x00000000
        context.expected.a = 0b11111111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x21) == 0b11111111, "Memory should remain unchanged")
    }

    @Test("EOR - zeropage,x mode")
    func testEOR_zeropageX() {
        var context = setupZeroPageX(opcode: 0x55, zeroPageAddress: 0x99, xOffset: 0x11, value: 0b10101010)
        context.cpu.registers.accumulator = 0b01010101
        context.expected.a = 0b11111111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0xAA) == 0b10101010, "Memory should remain unchanged")
    }

    @Test("EOR - (d,x) mode")
    func testEOR_indexedIndirect() {
        var context = setupIndexedIndirect(opcode: 0x41, zeroPageAddress: 0x00, xOffset: 0xFF, targetAddress: 0x0888, value: 0b00001111)
        context.cpu.registers.accumulator = 0b01001110
        context.expected.a = 0b01000001
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0888) == 0b00001111, "Memory should remain unchanged")
    }

    @Test("EOR - (d),y mode")
    func testEOR_indirectIndexed() {
        var contextNoCross = setupIndirectIndexed(opcode: 0x51, zeroPageAddress: 0x88, yOffset: 0x15, targetAddress: 0x0100, value: 0b10101010)
        contextNoCross.cpu.registers.accumulator = 0b10101010
        contextNoCross.expected.a = 0x00000000
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupIndirectIndexed(opcode: 0x51, zeroPageAddress: 0x88, yOffset: 0x15, targetAddress: 0x01EB, value: 0b10101010)
        contextWithCross.cpu.registers.accumulator = 0b10101010
        contextWithCross.expected.status = Status.zero
        contextWithCross.expected.a = 0x00000000
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0115) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0200) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }

    @Test("EOR - absolute mode")
    func testEOR_absolute() {
        var context = setupAbsolute(opcode: 0x4D, absoluteAddress: 0x1001, value: 0b10000000)
        context.cpu.registers.accumulator = 0b00000001
        context.expected.a = 0b10000001
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1001) == 0b10000000, "Memory should remain unchanged")
    }

    @Test("EOR - absolute,x mode")
    func testEOR_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0x5D, absoluteAddress: 0x09FE, xOffset: 0x01, value: 0b10101010)
        contextNoCross.cpu.registers.accumulator = 0b01010101
        contextNoCross.expected.a = 0b11111111
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0x5D, absoluteAddress: 0x09FF, xOffset: 0x01, value: 0b10101010)
        contextWithCross.cpu.registers.accumulator = 0b01010101
        contextWithCross.expected.a = 0b11111111
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x09FF) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0xA00) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }

    @Test("EOR - absolute,y mode")
    func testEOR_absoluteY() {
        var contextNoCross = setupAbsoluteY(opcode: 0x59, absoluteAddress: 0x0123, yOffset: 0xDC, value: 0b10000000)
        contextNoCross.cpu.registers.accumulator = 0b00000000
        contextNoCross.expected.a = 0b10000000
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteY(opcode: 0x59, absoluteAddress: 0x0123, yOffset: 0xDD, value: 0b10000000)
        contextWithCross.cpu.registers.accumulator = 0b00000000
        contextWithCross.expected.status = Status.negative
        contextWithCross.expected.a = 0b10000000
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x01FF) == 0b10000000, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0200) == 0b10000000, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("EOR - Flag behavior")
    func testEOR_flags() {
        func testEORFlags(a: UInt8, m: UInt8) -> Status {
            let context = setupImmediate(opcode: 0x49, value: m)
            context.cpu.registers.accumulator = a
            context.cpu.executeNextInstruction()
            
            return context.cpu.registers.status
        }
        
        // Test zero flag (same values cancel out)
        let test1 = testEORFlags(a: 0xFF, m: 0xFF)
        #expect(test1 == Status.zero,
               "XORing same values should result in zero")
        
        // Test negative flag (result has bit 7 set)
        let test2 = testEORFlags(a: 0x00, m: 0x80)
        #expect(test2 == Status.negative,
               "Result with bit 7 set should set negative flag")
        
        // Test no flags (positive non-zero result)
        let test3 = testEORFlags(a: 0x01, m: 0x02)
        #expect(test3 == Status.empty,
               "Positive non-zero result should set no flags")
        
        // Test preserving other flags (carry and overflow should be unaffected)
        let context = setupImmediate(opcode: 0x49, value: 0xFF)
        context.cpu.registers.accumulator = 0xFF
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow, .zero]),
               "EOR should preserve carry and overflow flags")
    }
    
    @Test("ORA - immediate mode")
    func testORA_immediate() {
        var context = setupImmediate(opcode: 0x09, value: 0b11111111)
        context.cpu.registers.accumulator = 0b00000000
        context.expected.a = 0b11111111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0b11111111, "Memory should remain unchanged")
    }

    @Test("ORA - zeropage mode")
    func testORA_zeropage() {
        var context = setupZeroPage(opcode: 0x05, zeroPageAddress: 0x21, value: 0b00000000)
        context.cpu.registers.accumulator = 0x00000000
        context.expected.a = 0b00000000
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x21) == 0b00000000, "Memory should remain unchanged")
    }

    @Test("ORA - zeropage,x mode")
    func testORA_zeropageX() {
        var context = setupZeroPageX(opcode: 0x15, zeroPageAddress: 0x99, xOffset: 0x11, value: 0b10101010)
        context.cpu.registers.accumulator = 0b01010101
        context.expected.a = 0b11111111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0xAA) == 0b10101010, "Memory should remain unchanged")
    }

    @Test("ORA - (d,x) mode")
    func testORA_indexedIndirect() {
        var context = setupIndexedIndirect(opcode: 0x01, zeroPageAddress: 0x00, xOffset: 0xFF, targetAddress: 0x0888, value: 0b00001111)
        context.cpu.registers.accumulator = 0b01010000
        context.expected.a = 0b01011111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0888) == 0b00001111, "Memory should remain unchanged")
    }

    @Test("ORA - (d),y mode")
    func testORA_indirectIndexed() {
        var context = setupIndirectIndexed(opcode: 0x11, zeroPageAddress: 0x88, yOffset: 0x15, targetAddress: 0x0100, value: 0b10101010)
        context.cpu.registers.accumulator = 0b10101010
        context.expected.a = 0b10101010
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0115) == 0b10101010, "Memory should remain unchanged")
    }

    @Test("ORA - absolute mode")
    func testORA_absolute() {
        var context = setupAbsolute(opcode: 0x0D, absoluteAddress: 0x1001, value: 0b10100000)
        context.cpu.registers.accumulator = 0b00001111
        context.expected.a = 0b10101111
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1001) == 0b10100000, "Memory should remain unchanged")
    }

    @Test("ORA - absolute,x mode with page crossing")
    func testORA_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0x1D, absoluteAddress: 0x09EF, xOffset: 0x01, value: 0b10101010)
        contextNoCross.cpu.registers.accumulator = 0b01010101
        contextNoCross.expected.a = 0b11111111
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0x1D, absoluteAddress: 0x09FF, xOffset: 0x01, value: 0b10101010)
        contextWithCross.cpu.registers.accumulator = 0b01010101
        contextWithCross.expected.a = 0b11111111
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x09F0) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0A00) == 0b10101010, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }

    @Test("ORA - absolute,y mode")
    func testORA_absoluteY() {
        var contextNoCross = setupAbsoluteY(opcode: 0x19, absoluteAddress: 0x0123, yOffset: 0xDC, value: 0b10000000)
        contextNoCross.cpu.registers.accumulator = 0b00000000
        contextNoCross.expected.a = 0b10000000
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteY(opcode: 0x19, absoluteAddress: 0x0123, yOffset: 0xDD, value: 0b10000000)
        contextWithCross.cpu.registers.accumulator = 0b00000000
        contextWithCross.expected.a = 0b10000000
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x01FF) == 0b10000000, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0200) == 0b10000000, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("ORA - Flag behavior")
    func testORA_flags() {
        func testORAFlags(a: UInt8, m: UInt8) -> Status {
            let context = setupImmediate(opcode: 0x09, value: m)
            context.cpu.registers.accumulator = a
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // Test zero flag (ORing zeros)
        let test1 = testORAFlags(a: 0x00, m: 0x00)
        #expect(test1 == Status.zero,
               "ORing zeros should result in zero")
        
        // Test negative flag (result has bit 7 set)
        let test2 = testORAFlags(a: 0x00, m: 0x80)
        #expect(test2 == Status.negative,
               "Result with bit 7 set should set negative flag")
        
        // Test no flags (positive non-zero result)
        let test3 = testORAFlags(a: 0x01, m: 0x02)
        #expect(test3 == Status.empty,
               "Positive non-zero result should set no flags")
        
        // Test result of ORing all bits
        let test4 = testORAFlags(a: 0xF0, m: 0x0F)
        #expect(test4 == Status.negative,
               "ORing 0xF0 with 0x0F should give 0xFF and set negative flag")
        
        // Test preserving other flags (carry and overflow should be unaffected)
        let context = setupImmediate(opcode: 0x09, value: 0x00)
        context.cpu.registers.accumulator = 0x00
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow, .zero]),
               "ORA should preserve carry and overflow flags")
    }
}
