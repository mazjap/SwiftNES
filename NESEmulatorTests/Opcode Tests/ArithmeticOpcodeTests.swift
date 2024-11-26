import Testing
@testable import NESEmulator

// Arithmetic Operations (ADC, SBC, INC, DEC, INX, INY, DEX, DEY)
@Suite("CPU Arithmetic Operations")
class ArithmeticOpcodeTests: OpcodeTestBase {
    
    // MARK: - ADC
    
    @Test("ADC - immediate mode ✓")
    func testADC_immediate() {
        var context = setupImmediate(opcode: 0x69, value: 0x42)
        context.cpu.registers.accumulator = 0x01
        context.expected.a = 0x43
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0x42, "Memory should remain unchanged")
    }
     
    @Test("ADC - zeropage mode ✓")
    func testADC_zeropage() {
        var context = setupZeroPage(opcode: 0x65, zeroPageAddress: 0x10, value: 0xA0)
        context.cpu.registers.status = Status.carry
        context.cpu.registers.accumulator = 0x10
        context.expected.a = 0xB1
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x10) == 0xA0, "Memory should remain unchanged")
    }
    
    @Test("ADC - zeropage,x mode ✓")
    func testADC_zeropageX() {
        var context = setupZeroPageX(opcode: 0x75, zeroPageAddress: 0xFF, xOffset: 0x01, value: 0x10)
        context.cpu.registers.accumulator = 0x99
        context.expected.a = 0xA9
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x00) == 0x10, "Memory should remain unchanged")
    }
        
    @Test("ADC - absolute mode ✓")
    func testADC_absolute() {
        var context = setupAbsolute(opcode: 0x6D, absoluteAddress: 0x1000, value: 0xAB)
        context.cpu.registers.status = Status.carry
        context.cpu.registers.accumulator = 0x50
        context.expected.a = 0xFC
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1000) == 0xAB, "Memory should remain unchanged")
    }
        
    @Test("ADC - absolute,x mode ✓")
    func testADC_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0x7D, absoluteAddress: 0x0123, xOffset: 0x02, value: 0xB5)
        contextNoCross.cpu.registers.accumulator = 0x10
        contextNoCross.expected.a = 0xC5
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0x7D, absoluteAddress: 0x01F0, xOffset: 0x10, value: 0xB5)
        contextWithCross.cpu.registers.accumulator = 0x10
        contextWithCross.expected.a = 0xC5
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0125) == 0xB5, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0200) == 0xB5, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
        
    @Test("ADC - absolute,y mode ✓")
    func testADC_absoluteY() {
        var contextNoCross = setupAbsoluteX(opcode: 0x7D, absoluteAddress: 0x0100, xOffset: 0x02, value: 0xAA)
        contextNoCross.cpu.registers.accumulator = 0x10
        contextNoCross.expected.a = 0xBA
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0x7D, absoluteAddress: 0x0101, xOffset: 0xFF, value: 0xAA)
        contextWithCross.cpu.registers.accumulator = 0x10
        contextWithCross.expected.a = 0xBA
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0102) == 0xAA, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0200) == 0xAA, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("ADC - (indirect,x) mode ✓")
    func testADC_indexedIndirect() {
        var context = setupIndexedIndirect(opcode: 0x61, zeroPageAddress: 0x05, xOffset: 0x05, targetAddress: 0x1000, value: 0x25)
        context.cpu.registers.accumulator = 0x10
        context.expected.a = 0x35
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1000) == 0x25, "Memory should remain unchanged")
    }
    
    @Test("ADC - (indirect),y mode ✓")
    func testADC_indirectIndexed() {
        var contextNoCross = setupIndirectIndexed(opcode: 0x71, zeroPageAddress: 0x41, yOffset: 0x10, targetAddress: 0x0800, value: 0xFA)
        contextNoCross.cpu.registers.accumulator = 0x04
        contextNoCross.expected.a = 0xFE
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupIndirectIndexed(opcode: 0x71, zeroPageAddress: 0x41, yOffset: 0x11, targetAddress: 0x07FF, value: 0xFA)
        contextWithCross.cpu.registers.accumulator = 0x04
        contextWithCross.expected.a = 0xFE
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0810) == 0xFA, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0810) == 0xFA, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("ADC - Flag behavior ✓")
    func testADC_flags() {
        func testADCFlags(a: UInt8, m: UInt8, carryIn: Bool = false) -> Status {
            let context = setupImmediate(opcode: 0x69, value: m)
            context.cpu.registers.accumulator = a
            context.cpu.registers.status.setFlag(.carry, to: carryIn)
            
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // Test 1: Simple addition, no flags set
        let test1 = testADCFlags(a: 0x05, m: 0x02)
        #expect(test1 == .empty, "N flag should not be set for positive result")
        
        // Test 2: Zero result
        let test2 = testADCFlags(a: 0xFF, m: 0x01)  // 255 + 1 = 0 with carry
        #expect(test2 == Status([.zero, .carry]), "Only Z and C flags should be set")
        
        // Test 3: Negative result (bit 7 set)
        let test3 = testADCFlags(a: 0x50, m: 0x50)  // 80 + 80 = 160 (-96 signed)
        #expect(test3 == Status([.negative, .overflow]), "Only N and Z flags should be set")
        
        // Test 4: Carry in affects result
        let test4 = testADCFlags(a: 0x50, m: 0x50, carryIn: true)  // 80 + 80 + 1 = 161
        #expect(test4 == Status([.negative, .overflow]), "Only N and Z flags should be set")
        
        // Test 5: Signed overflow without unsigned overflow
        let test5 = testADCFlags(a: 0x7F, m: 0x01)  // 127 + 1 = 128 (-128 signed)
        #expect(test5 == Status([.negative, .overflow]), "Only N and Z flags should be set")
        
        // Test 6: Both signed and unsigned overflow
        let test6 = testADCFlags(a: 0x80, m: 0x80)  // -128 + -128 = 0 (with carry)
        #expect(test6 == Status([.overflow, .zero, .carry]), "Only N, Z, C flags should be set")
    }
    
    // MARK: - DEC
    
    @Test("DEC - zeropage mode ✓")
    func testDEC_zeropage() {
        let context = setupZeroPage(opcode: 0xC6, zeroPageAddress: 0x15, value: 0xAA)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x15) == 0xA9)
    }
    
    @Test("DEC - Zeropage,x Mode ✓")
    func testDEC_zeropageX() {
        let context = setupZeroPageX(opcode: 0xD6, zeroPageAddress: 0x20, xOffset: 0x20, value: 0x5A)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x40) == 0x59)
    }
    
    @Test("DEC - absolute Mode ✓")
    func testDEC_absolute() {
        let context = setupAbsolute(opcode: 0xCE, absoluteAddress: 0x1EE7, value: 0x50)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1EE7) == 0x4F)
    }
    
    @Test("DEC - absoluteX Mode ✓")
    func testDEC_absoluteX() {
        let context = setupAbsoluteX(opcode: 0xDE, absoluteAddress: 0x1200, xOffset: 0x21, value: 0x02)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1221) == 0x01)
    }
    
    @Test("DEC - Flag behavior ✓")
    func testDEC_flags() {
        // Helper to run DEC and return flags and result
        func testDECFlags(m: UInt8) -> (flags: Status, result: UInt8) {
            let context = setupZeroPage(opcode: 0xC6, zeroPageAddress: 0x10, value: m)
            context.cpu.executeNextInstruction()
            
            return (context.cpu.registers.status,
                    context.mmu.read(from: 0x10))
        }
        
        // Test 1: Zero result (1 -> 0)
        let test1 = testDECFlags(m: 0x01)
        #expect(test1.flags == Status.zero,
               "Only Z flag should be set when result is zero")
        #expect(test1.result == 0, "1 - 1 should equal 0")
        
        // Test 2: Negative result (0 -> -1)
        let test2 = testDECFlags(m: 0x00)
        #expect(test2.flags == Status.negative,
               "Only N flag should be set when result is negative")
        #expect(test2.result == 0xFF, "0 - 1 should wrap to 255")
        
        // Test 3: Wrapping from 0x80 to 0x7F (negative to positive)
        let test3 = testDECFlags(m: 0x80)
        #expect(test3.flags == Status.empty,
               "No flags should be set when decrementing from -128 to 127")
        #expect(test3.result == 0x7F, "0x80 - 1 should equal 0x7F")
        
        // Test 4: Regular negative result (0x81 -> 0x80)
        let test4 = testDECFlags(m: 0x81)
        #expect(test4.flags == .negative,
               "N flag should be set when result is negative")
        #expect(test4.result == 0x80, "0x81 - 1 should equal 0x80")
        
        // Test 5: Multiple decrements maintain correct flags
        let context = setupZeroPage(opcode: 0xC6, zeroPageAddress: 0x10, value: 0x02)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == .empty,
               "No flags should be set after first decrement")
        #expect(context.mmu.read(from: 0x10) == 0x01, "First decrement should give 1")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == .zero,
               "Z flag should be set after second decrement")
        #expect(context.mmu.read(from: 0x10) == 0x00, "Second decrement should give 0")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == .negative,
               "N flag should be set after third decrement")
        #expect(context.mmu.read(from: 0x10) == 0xFF, "Third decrement should wrap to 255")
    }
    
    // MARK: - DEX
    
    @Test("DEX - implied mode ✓")
    func testDEX_implied() {
        var context = setupImplied(opcode: 0xCA)
        context.cpu.registers.indexX = 0xFF
        context.expected.x = 0xFE
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("DEX - Flag behavior ✓")
    func testDEX_flags() {
        // Helper to run DEX and return flags and result
        func testDEXFlags(x: UInt8) -> (flags: Status, result: UInt8) {
            let context = setupImplied(opcode: 0xCA)
            context.cpu.registers.indexX = x
            context.cpu.executeNextInstruction()
            
            return (context.cpu.registers.status,
                    context.cpu.registers.indexX)
        }
        
        // Test 1: Zero result (1 -> 0)
        let test1 = testDEXFlags(x: 0x01)
        #expect(test1.flags == Status.zero,
               "Only Z flag should be set when result is zero")
        #expect(test1.result == 0, "1 - 1 should equal 0")
        
        // Test 2: Negative result (0 -> -1)
        let test2 = testDEXFlags(x: 0x00)
        #expect(test2.flags == Status.negative,
               "Only N flag should be set when result is negative")
        #expect(test2.result == 0xFF, "0 - 1 should wrap to 255")
        
        // Test 3: Wrapping from 0x80 to 0x7F (negative to positive)
        let test3 = testDEXFlags(x: 0x80)
        #expect(test3.flags == Status.empty,
               "No flags should be set when decrementing from -128 to 127")
        #expect(test3.result == 0x7F, "0x80 - 1 should equal 0x7F")
        
        // Test 4: Regular negative result (0x81 -> 0x80)
        let test4 = testDEXFlags(x: 0x81)
        #expect(test4.flags == Status.negative,
               "N flag should be set when result is negative")
        #expect(test4.result == 0x80, "0x81 - 1 should equal 0x80")
        
        // Test 5: Multiple decrements maintain correct flags
        let context = setupImplied(opcode: 0xCA)
        context.cpu.registers.indexX = 0x02
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.empty,
               "No flags should be set after first decrement")
        #expect(context.cpu.registers.indexX == 0x01, "First decrement should give 1")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.zero,
               "Z flag should be set after second decrement")
        #expect(context.cpu.registers.indexX == 0x00, "Second decrement should give 0")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.negative,
               "N flag should be set after third decrement")
        #expect(context.cpu.registers.indexX == 0xFF, "Third decrement should wrap to 255")
    }
    
    // MARK: - DEY
    
    @Test("DEY - implied mode ✓")
    func testDEY_implied() {
        var context = setupImplied(opcode: 0x88)
        context.cpu.registers.indexY = 0xFF
        context.expected.y = 0xFE
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("DEY - Flag behavior ✓")
    func testDEY_flags() {
        // Helper to run DEY and return flags and result
        func testDEYFlags(y: UInt8) -> (flags: Status, result: UInt8) {
            let context = setupImplied(opcode: 0x88)
            context.cpu.registers.indexY = y
            context.cpu.executeNextInstruction()
            
            return (context.cpu.registers.status,
                    context.cpu.registers.indexY)
        }
        
        // Test 1: Zero result (1 -> 0)
        let test1 = testDEYFlags(y: 0x01)
        #expect(test1.flags == Status.zero,
               "Only Z flag should be set when result is zero")
        #expect(test1.result == 0, "1 - 1 should equal 0")
        
        // Test 2: Negative result (0 -> -1)
        let test2 = testDEYFlags(y: 0x00)
        #expect(test2.flags == Status.negative,
               "Only N flag should be set when result is negative")
        #expect(test2.result == 0xFF, "0 - 1 should wrap to 255")
        
        // Test 3: Wrapping from 0x80 to 0x7F (negative to positive)
        let test3 = testDEYFlags(y: 0x80)
        #expect(test3.flags == Status.empty,
               "No flags should be set when decrementing from -128 to 127")
        #expect(test3.result == 0x7F, "0x80 - 1 should equal 0x7F")
        
        // Test 4: Regular negative result (0x81 -> 0x80)
        let test4 = testDEYFlags(y: 0x81)
        #expect(test4.flags == Status.negative,
               "N flag should be set when result is negative")
        #expect(test4.result == 0x80, "0x81 - 1 should equal 0x80")
        
        // Test 5: Multiple decrements maintain correct flags
        let context = setupImplied(opcode: 0x88)
        context.cpu.registers.indexY = 0x02
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.empty,
               "No flags should be set after first decrement")
        #expect(context.cpu.registers.indexY == 0x01, "First decrement should give 1")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.zero,
               "Z flag should be set after second decrement")
        #expect(context.cpu.registers.indexY == 0x00, "Second decrement should give 0")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.negative,
               "N flag should be set after third decrement")
        #expect(context.cpu.registers.indexY == 0xFF, "Third decrement should wrap to 255")
    }
    
    // MARK: - INC
    
    @Test("INC - zeropage mode ✓")
    func testINC_zeropage() {
        let context = setupZeroPage(opcode: 0xE6, zeroPageAddress: 0x82, value: 0x84)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x82) == 0x85)
    }
    
    @Test("INC - zeropageX mode ✓")
    func testINC_zeropageX() {
        let context = setupZeroPageX(opcode: 0xF6, zeroPageAddress: 0x82, xOffset: 0x03, value: 0x48)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x85) == 0x49)
    }
    
    @Test("INC - absolute mode ✓")
    func testINC_absolute() {
        let context = setupAbsolute(opcode: 0xEE, absoluteAddress: 0x0987, value: 0x12)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0987) == 0x13)
    }
    
    @Test("INC - absoluteX mode ✓")
    func testINC_absoluteX() {
        let context = setupAbsoluteX(opcode: 0xFE, absoluteAddress: 0x0789, xOffset: 0x77, value: 0x21)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0800) == 0x22)
    }
    
    @Test("INC - Flag behavior ✓")
    func testINC_flags() {
        // Helper to run DEC and return flags and result
        func testINCFlags(m: UInt8) -> (flags: Status, result: UInt8) {
            let context = setupZeroPage(opcode: 0xE6, zeroPageAddress: 0x10, value: m)
            context.cpu.executeNextInstruction()
            
            return (context.cpu.registers.status,
                    context.mmu.read(from: 0x10))
        }
        
        // Test 1: Zero result (negative to positive) (255 -> 0)
        let test1 = testINCFlags(m: 0xFF)
        #expect(test1.flags == Status.zero,
               "Only Z flag should be set when result is zero")
        #expect(test1.result == 0, "255 + 1 should equal 0")
        
        // Test 2: Regular negative result (0x90 -> 0x91)
        let test2 = testINCFlags(m: 0x90)
        #expect(test2.flags == Status.negative,
               "Only N flag should be set when result is negative")
        #expect(test2.result == 0x91, "-117 + 1 should result in -116")
        
        // Test 3: Wrapping from 0x7F to 0x80 (positive to negative)
        let test3 = testINCFlags(m: 0x7F)
        #expect(test3.flags == Status.negative,
               "No flags should be set when decrementing from -128 to 127")
        #expect(test3.result == 0x80, "0x80 - 1 should equal 0x7F")
        
        // Test 4: Multiple increments maintain correct flags
        let context = setupZeroPage(opcode: 0xE6, zeroPageAddress: 0x10, value: 0xFE)
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.negative,
               "Negative flag should still be set after first increment")
        #expect(context.mmu.read(from: 0x10) == 0xFF, "First increment should give 0xFF")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.zero,
               "Z flag should be set after second increment")
        #expect(context.mmu.read(from: 0x10) == 0x00, "Second increment should wrap to 0")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.empty,
               "No flags should be set after third increment")
        #expect(context.mmu.read(from: 0x10) == 0x01, "Third increment should give 1")
    }
    
    
    // MARK: - INX
    
    @Test("INX - implied mode ✓")
    func testINX_implied() {
        var context = setupImplied(opcode: 0xE8)
        context.cpu.registers.indexX = 0xF0
        context.expected.x = 0xF1
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("INX - Flag behavior ✓")
    func testINX_flags() {
        // Helper to run DEX and return flags and result
        func testINXFlags(x: UInt8) -> (flags: Status, result: UInt8) {
            let context = setupImplied(opcode: 0xE8)
            context.cpu.registers.indexX = x
            context.cpu.executeNextInstruction()
            
            return (context.cpu.registers.status,
                    context.cpu.registers.indexX)
        }
        
        // Test 1: Zero result (negative to positive) (0xFF -> 0x00)
        let test1 = testINXFlags(x: 0xFF)
        #expect(test1.flags == Status.zero,
               "Only Z flag should be set when result is zero")
        #expect(test1.result == 0, "-1 + 1 should equal 0")
        
        // Test 2: Regular negative result (0x90 -> 0x91)
        let test2 = testINXFlags(x: 0x90)
        #expect(test2.flags == Status.negative,
               "Only N flag should be set when result is negative")
        #expect(test2.result == 0x91, "-117 + 1 should result in -116")
        
        // Test 3: Wrapping from 0x7F to 0x80 (positive to negative)
        let test3 = testINXFlags(x: 0x7F)
        #expect(test3.flags == Status.negative,
               "No flags should be set when decrementing from 127 to -128")
        #expect(test3.result == 0x80, "0x7F + 1 should equal 0x80")
        
        // Test 4: Multiple increments maintain correct flags
        let context = setupImplied(opcode: 0xE8)
        context.cpu.registers.indexX = 0xFE
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.negative,
               "N flag should be set after first increment")
        #expect(context.cpu.registers.indexX == 0xFF, "First increment should give 255")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.zero,
               "Z flag should be set after second increment")
        #expect(context.cpu.registers.indexX == 0x00, "Second increment should wrap to 0")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.empty,
               "No flag should be set after third increment")
        #expect(context.cpu.registers.indexX == 0x01, "Third increment should give 1")
    }
    
    // MARK: - INY
    
    @Test("INY - implied mode ✓")
    func testINY_implied() {
        var context = setupImplied(opcode: 0xC8)
        context.cpu.registers.indexY = 0xF0
        context.expected.y = 0xF1
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("INY - Flag behavior ✓")
    func testINY_flags() {
        // Helper to run DEX and return flags and result
        func testINYFlags(y: UInt8) -> (flags: Status, result: UInt8) {
            let context = setupImplied(opcode: 0xC8)
            context.cpu.registers.indexY = y
            context.cpu.executeNextInstruction()
            
            return (context.cpu.registers.status,
                    context.cpu.registers.indexY)
        }
        
        // Test 1: Zero result (negative to positive) (0xFF -> 0x00)
        let test1 = testINYFlags(y: 0xFF)
        #expect(test1.flags == Status.zero,
               "Only Z flag should be set when result is zero")
        #expect(test1.result == 0, "-1 + 1 should equal 0")
        
        // Test 2: Regular negative result (0x90 -> 0x91)
        let test2 = testINYFlags(y: 0x90)
        #expect(test2.flags == Status.negative,
               "Only N flag should be set when result is negative")
        #expect(test2.result == 0x91, "-117 + 1 should result in -116")
        
        // Test 3: Wrapping from 0x7F to 0x80 (positive to negative)
        let test3 = testINYFlags(y: 0x7F)
        #expect(test3.flags == Status.negative,
               "No flags should be set when decrementing from 127 to -128")
        #expect(test3.result == 0x80, "0x7F + 1 should equal 0x80")
        
        // Test 4: Multiple increments maintain correct flags
        let context = setupImplied(opcode: 0xC8)
        context.cpu.registers.indexY = 0xFE
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.negative,
               "N flag should be set after first increment")
        #expect(context.cpu.registers.indexY == 0xFF, "First increment should give 255")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.zero,
               "Z flag should be set after second increment")
        #expect(context.cpu.registers.indexY == 0x00, "Second increment should wrap to 0")
        
        context.cpu.registers.programCounter = context.initialPC
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status.empty,
               "No flag should be set after third increment")
        #expect(context.cpu.registers.indexY == 0x01, "Third increment should give 1")
    }
    
    // MARK: - SBC

    @Test("SBC - immediate mode ✓")
    func testSBC_immediate() {
        var context = setupImmediate(opcode: 0xE9, value: 0x42)
        context.cpu.registers.status = Status.carry
        context.cpu.registers.accumulator = 0x01
        context.expected.a = 0xBF
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0x42, "Memory should remain unchanged")
    }

    @Test("SBC - immediate mode 2 (SBC + NOP) ✓")
    func testSBC_immediate2() {
        var context = setupImmediate(opcode: 0xEB, value: 0x42)
        context.cpu.registers.accumulator = 0x50
        context.expected.a = 0x0D
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0x42, "Memory should remain unchanged")
    }
     
    @Test("SBC - zeropage mode ✓")
    func testSBC_zeropage() {
        var context = setupZeroPage(opcode: 0xE5, zeroPageAddress: 0x10, value: 0x10)
        context.cpu.registers.status = Status.carry
        context.cpu.registers.accumulator = 0xA0
        context.expected.a = 0x90
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x10) == 0x10, "Memory should remain unchanged")
    }

    @Test("SBC - zeropage,x mode ✓")
    func testSBC_zeropageX() {
        var context = setupZeroPageX(opcode: 0xF5, zeroPageAddress: 0xFF, xOffset: 0x01, value: 0x10)
        context.cpu.registers.accumulator = 0x99
        context.expected.a = 0x88
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x00) == 0x10, "Memory should remain unchanged")
    }
        
    @Test("SBC - absolute mode ✓")
    func testSBC_absolute() {
        var context = setupAbsolute(opcode: 0xED, absoluteAddress: 0x1000, value: 0x50)
        context.cpu.registers.status = Status.carry
        context.cpu.registers.accumulator = 0xAB
        context.expected.a = 0x5B
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1000) == 0x50, "Memory should remain unchanged")
    }
        
    @Test("SBC - absolute,x mode ✓")
    func testSBC_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0xFD, absoluteAddress: 0x0123, xOffset: 0x10, value: 0x10)
        contextNoCross.cpu.registers.accumulator = 0xB5
        contextNoCross.expected.a = 0xA4
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0xFD, absoluteAddress: 0x01F0, xOffset: 0x10, value: 0x10)
        contextWithCross.cpu.registers.accumulator = 0xB5
        contextWithCross.expected.a = 0xA4
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0133) == 0x10, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0200) == 0x10, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }
    
    @Test("SBC - absolute,y mode ✓")
    func testSBC_absoluteY() {
        var contextNoCross = setupAbsoluteY(opcode: 0xF9, absoluteAddress: 0x1200, yOffset: 0x02, value: 0xB5)
        contextNoCross.cpu.registers.accumulator = 0x10
        contextNoCross.expected.a = 0x5A
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteY(opcode: 0xF9, absoluteAddress: 0x12FF, yOffset: 0x02, value: 0xB5)
        contextWithCross.cpu.registers.accumulator = 0x10
        contextWithCross.expected.a = 0x5A
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x1202) == 0xB5, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x1301) == 0xB5, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }

    @Test("SBC - (indirect,x) mode ✓")
    func testSBC_indexedIndirect() {
        var context = setupIndexedIndirect(opcode: 0xE1, zeroPageAddress: 0x05, xOffset: 0x05, targetAddress: 0x1000, value: 0x10)
        context.cpu.registers.accumulator = 0x25
        context.expected.a = 0x14
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1000) == 0x10, "Memory should remain unchanged")
    }

    @Test("SBC - (indirect),y mode ✓")
    func testSBC_indirectIndexed() {
        var contextNoCross = setupIndirectIndexed(opcode: 0xF1, zeroPageAddress: 0x41, yOffset: 0x11, targetAddress: 0x0810, value: 0x05)
        contextNoCross.cpu.registers.accumulator = 0xFF
        contextNoCross.expected.a = 0xF9
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupIndirectIndexed(opcode: 0xF1, zeroPageAddress: 0x41, yOffset: 0xF0, targetAddress: 0x0810, value: 0x05)
        contextWithCross.cpu.registers.accumulator = 0xFF
        contextWithCross.expected.a = 0xF9
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0821) == 0x05, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0900) == 0x05, "Memory should remain unchanged")
        #expect(contextWithCross.cpu.clockCycleCount == contextNoCross.cpu.clockCycleCount + 1)
    }

    @Test("SBC - Flag behavior ✓")
    func testSBC_flags() {
        // Helper to run SBC and return flags
        func testSBCFlags(a: UInt8, m: UInt8, carryIn: Bool = true) -> (
            result: UInt8,
            signedResult: Int8,
            carrySet: Bool,
            overflowSet: Bool,
            negativeSet: Bool,
            zeroSet: Bool
        ) {
            let context = setupImmediate(opcode: 0xE9, value: m)
            context.cpu.registers.accumulator = a
            context.cpu.registers.status.setFlag(.carry, to: carryIn)
            
            context.cpu.executeNextInstruction()
            
            return (
                result: context.cpu.registers.accumulator,
                signedResult: Int8(bitPattern: context.cpu.registers.accumulator),
                carrySet: context.cpu.registers.status.readFlag(.carry),
                overflowSet: context.cpu.registers.status.readFlag(.overflow),
                negativeSet: context.cpu.registers.status.readFlag(.negative),
                zeroSet: context.cpu.registers.status.readFlag(.zero)
            )
        }
        
        // Test 1: Simple subtraction
        let test1 = testSBCFlags(a: 0x50, m: 0x10)  // 80 - 16 = 64
        #expect(test1.result == 0x40, "0x50 - 0x10 should equal 0x40")
        #expect(test1.carrySet == true, "No borrow needed")
        #expect(test1.overflowSet == false, "No overflow in simple subtraction")
        
        // Test 2: Subtraction with borrow
        let test2 = testSBCFlags(a: 0x50, m: 0x60)  // 80 - 96 = -16
        #expect(test2.result == 0xF0, "0x50 - 0x60 should equal 0xF0")
        #expect(test2.carrySet == false, "Should borrow")
        #expect(test2.negativeSet == true, "Result is negative")
        
        // Test 3: Overflow case
        let test3 = testSBCFlags(a: 0x80, m: 0x01)  // -128 - 1 = -129 (overflow)
        #expect(test3.result == 0x7F, "0x80 - 0x01 should equal 0x7F")
        #expect(test3.carrySet == true, "Overflow when result exceeds signed range")
        #expect(test3.overflowSet == true, "Overflow when result exceeds signed range")
        #expect(test3.negativeSet == false, "Result appears positive due to overflow")
        
        // Test 4: Zero result
        let test4 = testSBCFlags(a: 0x42, m: 0x42)  // 66 - 66 = 0
        #expect(test4.result == 0x00, "0x42 - 0x42 should equal 0")
        #expect(test4.zeroSet == true, "Zero flag should be set")
        #expect(test4.carrySet == true, "No borrow needed")
        
        // Test 5: Carry affects subtraction
        let test5 = testSBCFlags(a: 0x42, m: 0x42, carryIn: false)  // 66 - 66 - 1 = -1
        #expect(test5.result == 0xFF, "0x42 - 0x42 - 1 should equal 0xFF")
        #expect(test5.negativeSet == true, "Result is negative")
        
        // Test 6: Chain of borrows
        let test6 = testSBCFlags(a: 0x00, m: 0x01)  // 0 - 1 = -1 (with chain of borrows)
        #expect(test6.result == 0xFF, "0x00 - 0x01 should equal 0xFF")
        #expect(test6.carrySet == false, "Should need to borrow")
        #expect(test6.negativeSet == true, "Result is negative")
        
        // Test 7: Negative - Negative
        let test7 = testSBCFlags(a: 0x80, m: 0xFF)  // -128 - (-1) = -127 (0x81)
        #expect(test7.result == 0x81, "0x80 - 0xFF")
        #expect(test7.overflowSet == false, "No overflow when result is in range")
        #expect(test7.negativeSet == true, "Result is negative")
    }
}
