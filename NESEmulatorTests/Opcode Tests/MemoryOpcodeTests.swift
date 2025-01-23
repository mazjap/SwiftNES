import Testing
@testable import NESEmulator

// Memory Operations (LDA, LDX, LDY, NOP, STA, STX, STY, TAX, TAY, TSX, TXA, TXS, TYA)
@Suite("CPU Memory Operations")
class MemoryOpcodeTests: OpcodeTestBase {
    @Test("LDA - immediate mode")
    func LDA_immediate() {
        var context = setupImmediate(opcode: 0xA9, value: 0x7F)
        context.expected.a = 0x7F
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0x7F, "Memory should remain unchanged")
    }

    @Test("LDA - zeropage mode")
    func LDA_zeropage() {
        var context = setupZeroPage(opcode: 0xA5, zeroPageAddress: 0x00, value: 0x80)
        context.expected.a = 0x80
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x00) == 0x80, "Memory should remain unchanged")
    }

    @Test("LDA - zeropage,x mode")
    func LDA_zeropageX() {
        var context = setupZeroPageX(opcode: 0xB5, zeroPageAddress: 0x40, xOffset: 0x40, value: 0x00)
        context.cpu.registers.accumulator = 0xFF // Set to a value other than 0 to ensure proper testing
        context.expected.a = 0x00
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x80) == 0x00, "Memory should remain unchanged")
    }

    @Test("LDA - (d,x) mode")
    func LDA_indexedIndirect() {
        var context = setupIndexedIndirect(opcode: 0xA1, zeroPageAddress: 0x25, xOffset: 0x50, targetAddress: 0x0513, value: 0x55)
        context.expected.a = 0x55
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0513) == 0x55, "Memory should remain unchanged")
    }

    @Test("LDA - (d),y mode")
    func LDA_indirectIndexed() {
        var contextNoCross = setupIndirectIndexed(opcode: 0xB1, zeroPageAddress: 0x55, yOffset: 0x20, targetAddress: 0x0315, value: 0xFF)
        contextNoCross.expected.a = 0xFF
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupIndirectIndexed(opcode: 0xB1, zeroPageAddress: 0x55, yOffset: 0xEB, targetAddress: 0x0315, value: 0xFF)
        contextWithCross.expected.a = 0xFF
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x0335) == 0xFF, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0400) == 0xFF, "Memory should remain unchanged")
        #expect(contextWithCross.expected.cycles == contextNoCross.expected.cycles + 1)
    }

    @Test("LDA - absolute mode")
    func LDA_absolute() {
        var context = setupAbsolute(opcode: 0xAD, absoluteAddress: 0x1000, value: 0x20)
        context.expected.a = 0x20
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1000) == 0x20)
    }

    @Test("LDA - absolute,x mode")
    func LDA_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0xBD, absoluteAddress: 0x10FE, xOffset: 0x01, value: 0x00)
        contextNoCross.cpu.registers.accumulator = 0x01
        contextNoCross.expected.a = 0x00
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0xBD, absoluteAddress: 0x10FF, xOffset: 0x01, value: 0x00)
        contextWithCross.cpu.registers.accumulator = 0x01
        contextWithCross.expected.a = 0x00
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x10FF) == 0x00, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x1100) == 0x00, "Memory should remain unchanged")
        #expect(contextWithCross.expected.cycles == contextNoCross.expected.cycles + 1)
    }

    @Test("LDA - absolute,y mode")
    func LDA_absoluteY() {
        var contextNoCross = setupAbsoluteY(opcode: 0xB9, absoluteAddress: 0x1321, yOffset: 0x12, value: 0x95)
        contextNoCross.expected.a = 0x95
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteY(opcode: 0xB9, absoluteAddress: 0x1321, yOffset: 0xDF, value: 0x95)
        contextWithCross.expected.a = 0x95
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x1333) == 0x95, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x1400) == 0x95, "Memory should remain unchanged")
        #expect(contextWithCross.expected.cycles == contextNoCross.expected.cycles + 1)
    }
    
    @Test("LDA - Flag behavior")
    func testLDA_flags() {
        func testLDAFlags(value: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImmediate(opcode: 0xA9, value: value)
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.accumulator, context.cpu.registers.status)
        }
        
        // Test loading zero sets zero flag
        let test1 = testLDAFlags(value: 0x00)
        #expect(test1.result == 0x00, "Loading 0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Loading zero should set zero flag")
        
        // Test loading negative number sets negative flag
        let test2 = testLDAFlags(value: 0x80)
        #expect(test2.result == 0x80, "Loading 0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Loading negative number should set negative flag")
        
        // Test loading positive number sets no flags
        let test3 = testLDAFlags(value: 0x01)
        #expect(test3.result == 0x01, "Loading 0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Loading positive non-zero number should set no flags")
        
        // Test preserving carry and overflow flags
        let context = setupImmediate(opcode: 0xA9, value: 0x40)
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "LDA should preserve carry and overflow flags")
    }
    
    @Test("LDX - immediate mode")
    func LDX_immediate() {
        var context = setupImmediate(opcode: 0xA2, value: 0x00)
        context.cpu.registers.indexX = 0xFF // Set to a value other than 0 to ensure proper testing
        context.expected.x = 0x00
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0x00, "Memory should remain unchanged")
    }

    @Test("LDX - zeropage mode")
    func LDX_zeropage() {
        var context = setupZeroPage(opcode: 0xA6, zeroPageAddress: 0x64, value: 0x80)
        context.expected.x = 0x80
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x64) == 0x80, "Memory should remain unchanged")
    }

    @Test("LDX - zeropage,y mode")
    func LDX_zeropageY() {
        var context = setupZeroPageY(opcode: 0xB6, zeroPageAddress: 0x50, yOffset: 0x14, value: 0x01)
        context.expected.x = 0x01
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x64) == 0x01, "Memory should remain unchanged")
    }

    @Test("LDX - absolute mode")
    func LDX_absolute() {
        var context = setupAbsolute(opcode: 0xAE, absoluteAddress: 0x0200, value: 0xFF)
        context.expected.x = 0xFF
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0200) == 0xFF, "Memory should remain unchanged")
    }

    @Test("LDX - absolute,y mode")
    func LDX_absoluteY() {
        var contextNoCross = setupAbsoluteY(opcode: 0xBE, absoluteAddress: 0x07FE, yOffset: 0x01, value: 0x55)
        contextNoCross.expected.x = 0x55
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteY(opcode: 0xBE, absoluteAddress: 0x07FF, yOffset: 0x01, value: 0x55)
        contextWithCross.expected.x = 0x55
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x07FF) == 0x55, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0800) == 0x55, "Memory should remain unchanged")
        #expect(contextWithCross.expected.cycles == contextNoCross.expected.cycles + 1)
    }
    
    @Test("LDX - Flag behavior")
    func testLDX_flags() {
        func testLDXFlags(value: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImmediate(opcode: 0xA2, value: value)
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.indexX, context.cpu.registers.status)
        }
        
        // Test loading zero sets zero flag
        let test1 = testLDXFlags(value: 0x00)
        #expect(test1.result == 0x00, "Loading 0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Loading zero should set zero flag")
        
        // Test loading negative number sets negative flag
        let test2 = testLDXFlags(value: 0x80)
        #expect(test2.result == 0x80, "Loading 0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Loading negative number should set negative flag")
        
        // Test loading positive number sets no flags
        let test3 = testLDXFlags(value: 0x01)
        #expect(test3.result == 0x01, "Loading 0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Loading positive non-zero number should set no flags")
        
        // Test preserving carry and overflow flags
        let context = setupImmediate(opcode: 0xA2, value: 0x40)
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "LDX should preserve carry and overflow flags")
    }
    
    @Test("LDY - immediate mode")
    func LDY_immediate() {
        var context = setupImmediate(opcode: 0xA0, value: 0x00)
        context.cpu.registers.indexY = 0xFF // Set to a value other than 0 to ensure proper testing
        context.expected.y = 0x00
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x8001) == 0x00, "Memory should remain unchanged")
    }

    @Test("LDY - zeropage mode")
    func LDY_zeropage() {
        var context = setupZeroPage(opcode: 0xA4, zeroPageAddress: 0x64, value: 0x80)
        context.expected.y = 0x80
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x64) == 0x80, "Memory should remain unchanged")
    }

    @Test("LDY - zeropage,x mode")
    func LDY_zeropageX() {
        var context = setupZeroPageX(opcode: 0xB4, zeroPageAddress: 0x50, xOffset: 0x14, value: 0x01)
        context.expected.y = 0x01
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x64) == 0x01, "Memory should remain unchanged")
    }

    @Test("LDY - absolute mode")
    func LDY_absolute() {
        var context = setupAbsolute(opcode: 0xAC, absoluteAddress: 0x0200, value: 0xFF)
        context.expected.y = 0xFF
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x0200) == 0xFF, "Memory should remain unchanged")
    }

    @Test("LDX - absolute,x mode")
    func LDY_absoluteX() {
        var contextNoCross = setupAbsoluteX(opcode: 0xBC, absoluteAddress: 0x07FE, xOffset: 0x01, value: 0x55)
        contextNoCross.expected.y = 0x55
        
        contextNoCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextNoCross)
        
        
        var contextWithCross = setupAbsoluteX(opcode: 0xBC, absoluteAddress: 0x07FF, xOffset: 0x01, value: 0x55)
        contextWithCross.expected.y = 0x55
        
        contextWithCross.cpu.executeNextInstruction()
        verifyCPUState(context: contextWithCross)
        
        #expect(contextNoCross.mmu.read(from: 0x07FF) == 0x55, "Memory should remain unchanged")
        #expect(contextWithCross.mmu.read(from: 0x0800) == 0x55, "Memory should remain unchanged")
        #expect(contextWithCross.expected.cycles == contextNoCross.expected.cycles + 1)
    }
    
    @Test("LDY - Flag behavior")
    func testLDY_flags() {
        func testLDYFlags(value: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImmediate(opcode: 0xA0, value: value)
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.indexY, context.cpu.registers.status)
        }
        
        // Test loading zero sets zero flag
        let test1 = testLDYFlags(value: 0x00)
        #expect(test1.result == 0x00, "Loading 0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Loading zero should set zero flag")
        
        // Test loading negative number sets negative flag
        let test2 = testLDYFlags(value: 0x80)
        #expect(test2.result == 0x80, "Loading 0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Loading negative number should set negative flag")
        
        // Test loading positive number sets no flags
        let test3 = testLDYFlags(value: 0x01)
        #expect(test3.result == 0x01, "Loading 0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Loading positive non-zero number should set no flags")
        
        // Test preserving carry and overflow flags
        let context = setupImmediate(opcode: 0xA0, value: 0x40)
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "LDY should preserve carry and overflow flags")
    }
    
    @Test("NOP - implied mode (official)")
    func testNOP_implied() {
        let context = setupImplied(opcode: 0xEA)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    // Illegal NOP variants
    
    @Test("NOP - implied mode variants 🧪", arguments: [0x1A, 0x3A, 0x5A, 0x7A, 0xDA, 0xFA])
    func testNOP_implied_variants(opcode: UInt8) {
        let context = setupImplied(opcode: opcode)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("NOP - immediate mode variants 🧪", arguments: [0x80, 0x82, 0x89, 0xC2, 0xE2])
    func testNOP_immediate(opcode: UInt8) {
        let context = setupImmediate(opcode: opcode, value: 0x42)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("NOP - zeropage mode variants 🧪", arguments: [0x04, 0x44, 0x64])
    func testNOP_zeropage(opcode: UInt8) {
        let context = setupZeroPage(opcode: opcode, zeroPageAddress: 0x42, value: 0xFF)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("NOP - zeropage,x mode variants 🧪", arguments: [0x14, 0x34, 0x54, 0x74, 0xD4, 0xF4])
    func testNOP_zeropageX(opcode: UInt8) {
        let context = setupZeroPageX(opcode: opcode, zeroPageAddress: 0x42, xOffset: 0x10, value: 0xFF)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("NOP - absolute mode variants 🧪")
    func testNOP_absolute() {
        // Test all absolute NOPs (0x0C)
        let context = setupAbsolute(opcode: 0x0C, absoluteAddress: 0x1234, value: 0xFF)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }

    @Test("NOP - absolute,x mode variants 🧪", arguments: [0x1C, 0x3C, 0x5C, 0x7C, 0xDC, 0xFC])
    func testNOP_absoluteX(opcode: UInt8) {
        let context = setupAbsoluteX(opcode: opcode, absoluteAddress: 0x1234, xOffset: 0x10, value: 0xFF)
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("NOP - Flag behavior")
    func testNOP_flags() {
        func testNOPFlags(value: UInt8, setAllFlags: Bool) -> Status {
            let context = setupImplied(opcode: 0xEA)
            context.cpu.registers.status = setAllFlags ? Status(rawValue: 0xFF) : Status.empty
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // Test no flags are affected
        let test1 = testNOPFlags(value: 0x01, setAllFlags: true)
        #expect(test1 == Status(rawValue: 0xFF),
               "NOP should not clear flags")
        
        // Test no flags are affected
        let test2 = testNOPFlags(value: 0x01, setAllFlags: false)
        #expect(test2 == Status.empty,
               "NOP should not set flags")
    }
    
    @Test("STA - zeropage mode")
    func STA_zeropage() {
        let context = setupZeroPage(opcode: 0x85, zeroPageAddress: 0x42, value: 0xFF) // Initial value doesn't matter
        context.cpu.registers.accumulator = 0x37 // Value to store
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x42) == 0x37, "Value from accumulator should be stored in memory")
    }
    
    @Test("STA - zeropage,x mode")
    func STA_zeropageX() {
        let context = setupZeroPageX(opcode: 0x95, zeroPageAddress: 0x42, xOffset: 0x10, value: 0xFF)
        context.cpu.registers.accumulator = 0x55
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x52) == 0x55, "Value should be stored at wrapped zero-page address")
    }
    
    @Test("STA - (d,x) mode")
    func STA_indexedIndirect() {
        let context = setupIndexedIndirect(opcode: 0x81, zeroPageAddress: 0x20, xOffset: 0x05, targetAddress: 0x1234, value: 0xFF)
        context.cpu.registers.accumulator = 0x42
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1234) == 0x42, "Value should be stored at indirect address")
    }
    
    @Test("STA - (d),y mode")
    func STA_indirectIndexed() {
        let context = setupIndirectIndexed(opcode: 0x91, zeroPageAddress: 0x20, yOffset: 0x05, targetAddress: 0x1234, value: 0xFF)
        context.cpu.registers.accumulator = 0x80
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1239) == 0x80, "Value should be stored at indexed address")
    }
    
    @Test("STA - absolute mode")
    func STA_absolute() {
        let context = setupAbsolute(opcode: 0x8D, absoluteAddress: 0x1234, value: 0xFF)
        context.cpu.registers.accumulator = 0xAA
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1234) == 0xAA, "Value should be stored at absolute address")
    }
    
    @Test("STA - absolute,x mode")
    func STA_absoluteX() {
        let context = setupAbsoluteX(opcode: 0x9D, absoluteAddress: 0x1234, xOffset: 0x10, value: 0xFF)
        context.cpu.registers.accumulator = 0xDD
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1244) == 0xDD, "Value should be stored at indexed address")
    }
    
    @Test("STA - absolute,y mode")
    func STA_absoluteY() {
        let context = setupAbsoluteY(opcode: 0x99, absoluteAddress: 0x1234, yOffset: 0x10, value: 0xFF)
        context.cpu.registers.accumulator = 0x00
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1244) == 0x00, "Value should be stored at indexed address")
    }
    
    @Test("STX - zeropage mode")
    func STX_zeropage() {
        let context = setupZeroPage(opcode: 0x86, zeroPageAddress: 0x38, value: 0xFF)
        context.cpu.registers.indexX = 0x01
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x38) == 0x01, "Value should be stored at indexed address")
    }
    
    @Test("STX - zeropage,y mode")
    func STX_zeropageY() {
        let context = setupZeroPageY(opcode: 0x96, zeroPageAddress: 0x38, yOffset: 0x07, value: 0x30)
        context.cpu.registers.indexX = 0xFF
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x3F) == 0xFF, "Value should be stored at indexed address")
    }
    
    @Test("STX - absolute mode")
    func STX_absolute() {
        let context = setupAbsolute(opcode: 0x8E, absoluteAddress: 0x1999, value: 0xFF)
        context.cpu.registers.indexX = 0x27
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1999) == 0x27, "Value should be stored at indexed address")
    }
    
    @Test("STY - zeropage mode")
    func STY_zeropage() {
        let context = setupZeroPage(opcode: 0x84, zeroPageAddress: 0x83, value: 0xFF)
        context.cpu.registers.indexY = 0x88
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x83) == 0x88, "Value should be stored at indexed address")
    }
    
    @Test("STY - zeropage,x mode")
    func STY_zeropageX() {
        let context = setupZeroPageX(opcode: 0x94, zeroPageAddress: 0x83, xOffset: 0x02, value: 0xFF)
        context.cpu.registers.indexY = 0x5F
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x85) == 0x5F, "Value should be stored at indexed address")
    }
    
    @Test("STY - absolute mode")
    func STY_absolute() {
        let context = setupAbsolute(opcode: 0x8C, absoluteAddress: 0x1555, value: 0xFF)
        context.cpu.registers.indexY = 0x00
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
        
        #expect(context.mmu.read(from: 0x1555) == 0x00, "Value should be stored at indexed address")
    }
    
    @Test("Store instructions never affect flags")
    func testStore_flags() {
        // Use 0xFF to set all status flags (even unused ones)
        let allFlags = Status(rawValue: 0xFF)
        
        func setupStoreFlags(opcode: UInt8, withAllFlags: Bool) -> Status {
            let context = setupZeroPage(opcode: 0x85, zeroPageAddress: 0x42, value: 0xFF)
            context.cpu.registers.status = withAllFlags ? allFlags : Status.empty
            context.cpu.registers.accumulator = 0x42
            context.cpu.executeNextInstruction()
            
            return context.cpu.registers.status
        }
        
        #expect(setupStoreFlags(opcode: 0x85, withAllFlags: true) == allFlags,
               "STA should preserve all flags when set")
        #expect(setupStoreFlags(opcode: 0x85, withAllFlags: false) == .empty,
               "STA should preserve all flags when clear")
        
        #expect(setupStoreFlags(opcode: 0x86, withAllFlags: true) == allFlags,
               "STX should preserve all flags when set")
        #expect(setupStoreFlags(opcode: 0x86, withAllFlags: false) == .empty,
               "STX should preserve all flags when clear")
        
        #expect(setupStoreFlags(opcode: 0x84, withAllFlags: true) == allFlags,
               "STY should preserve all flags when set")
        #expect(setupStoreFlags(opcode: 0x84, withAllFlags: false) == .empty,
               "STY should preserve all flags when clear")
    }
    
    @Test("TAX - implied mode")
    func TAX_implied() {
        var context = setupImplied(opcode: 0xAA)
        context.cpu.registers.accumulator = 0x05
        context.expected.x = 0x05
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("TAX - Flag behavior")
    func testTAX_flags() {
        func testTAXFlags(accumulator: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0xAA)
            context.cpu.registers.accumulator = accumulator
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.indexX, context.cpu.registers.status)
        }
        
        // Test zero flag when transferring zero
        let test1 = testTAXFlags(accumulator: 0x00)
        #expect(test1.result == 0x00, "Transferring 0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Transferring zero should set zero flag")
        
        // Test negative flag when transferring negative number
        let test2 = testTAXFlags(accumulator: 0x80)
        #expect(test2.result == 0x80, "Transferring 0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Transferring negative number should set negative flag")
        
        // Test no flags when transferring positive number
        let test3 = testTAXFlags(accumulator: 0x01)
        #expect(test3.result == 0x01, "Transferring 0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Transferring positive non-zero number should set no flags")
        
        // Test preserving unaffected flags
        let context = setupImplied(opcode: 0xAA)
        context.cpu.registers.accumulator = 0x40
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "TAX should preserve carry and overflow flags")
    }
    
    @Test("TAY - implied mode")
    func TAY_implied() {
        var context = setupImplied(opcode: 0xA8)
        context.cpu.registers.accumulator = 0xFF
        context.expected.y = 0xFF
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("TAY - Flag behavior")
    func testTAY_flags() {
        func testTAYFlags(accumulator: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0xA8)
            context.cpu.registers.accumulator = accumulator
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.indexY, context.cpu.registers.status)
        }
        
        // Test zero flag when transferring zero
        let test1 = testTAYFlags(accumulator: 0x00)
        #expect(test1.result == 0x00, "Transferring 0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Transferring zero should set zero flag")
        
        // Test negative flag when transferring negative number
        let test2 = testTAYFlags(accumulator: 0x80)
        #expect(test2.result == 0x80, "Transferring 0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Transferring negative number should set negative flag")
        
        // Test no flags when transferring positive number
        let test3 = testTAYFlags(accumulator: 0x01)
        #expect(test3.result == 0x01, "Transferring 0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Transferring positive non-zero number should set no flags")
        
        // Test preserving unaffected flags
        let context = setupImplied(opcode: 0xA8)
        context.cpu.registers.accumulator = 0x40
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "TAY should preserve carry and overflow flags")
    }
    
    @Test("TSX - implied mode")
    func TSX_implied() {
        var context = setupImplied(opcode: 0xBA)
        context.cpu.registers.stackPointer = 0x00
        context.cpu.registers.indexX = 0xFF
        context.expected.x = 0x00
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("TSX - Flag behavior")
    func testTSX_flags() {
        func testTSXFlags(stackPointer: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0xBA)
            context.cpu.registers.stackPointer = stackPointer
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.indexX, context.cpu.registers.status)
        }
        
        // Test zero flag when transferring zero
        let test1 = testTSXFlags(stackPointer: 0x00)
        #expect(test1.result == 0x00, "Transferring SP=0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Transferring zero should set zero flag")
        
        // Test negative flag when transferring negative number
        let test2 = testTSXFlags(stackPointer: 0x80)
        #expect(test2.result == 0x80, "Transferring SP=0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Transferring negative number should set negative flag")
        
        // Test no flags when transferring positive number
        let test3 = testTSXFlags(stackPointer: 0x01)
        #expect(test3.result == 0x01, "Transferring SP=0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Transferring positive non-zero number should set no flags")
        
        // Test preserving unaffected flags
        let context = setupImplied(opcode: 0xBA)
        context.cpu.registers.stackPointer = 0x40
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "TSX should preserve carry and overflow flags")
    }
    
    @Test("TXA - implied mode")
    func TXA_implied() {
        var context = setupImplied(opcode: 0x8A)
        context.cpu.registers.indexX = 0xBB
        context.expected.a = 0xBB
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("TXA - Flag behavior")
    func testTXA_flags() {
        func testTXAFlags(xRegister: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0x8A)
            context.cpu.registers.indexX = xRegister
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.accumulator, context.cpu.registers.status)
        }
        
        // Test zero flag when transferring zero
        let test1 = testTXAFlags(xRegister: 0x00)
        #expect(test1.result == 0x00, "Transferring X=0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Transferring zero should set zero flag")
        
        // Test negative flag when transferring negative number
        let test2 = testTXAFlags(xRegister: 0x80)
        #expect(test2.result == 0x80, "Transferring X=0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Transferring negative number should set negative flag")
        
        // Test no flags when transferring positive number
        let test3 = testTXAFlags(xRegister: 0x01)
        #expect(test3.result == 0x01, "Transferring X=0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Transferring positive non-zero number should set no flags")
        
        // Test preserving unaffected flags
        let context = setupImplied(opcode: 0x8A)
        context.cpu.registers.indexX = 0x40
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "TXA should preserve carry and overflow flags")
    }
    
    @Test("TXS - implied mode")
    func TXS_implied() {
        var context = setupImplied(opcode: 0x9A)
        context.cpu.registers.indexX = 0xF0
        context.expected.sp = 0xF0
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("TXS - Flag behavior")
    func testTXS_flags() {
        func testTXSFlags(xRegister: UInt8, initialFlags: Status) -> Status {
            let context = setupImplied(opcode: 0x9A)
            context.cpu.registers.indexX = xRegister
            context.cpu.registers.status = initialFlags
            context.cpu.executeNextInstruction()
            return context.cpu.registers.status
        }
        
        // Test flags preserved when transferring zero
        let test1 = testTXSFlags(xRegister: 0x00, initialFlags: Status([.zero, .negative]))
        #expect(test1 == Status([.zero, .negative]),
               "TXS should preserve all flags even when transferring zero")
        
        // Test flags preserved when transferring negative number
        let test2 = testTXSFlags(xRegister: 0x80, initialFlags: Status([.carry, .overflow]))
        #expect(test2 == Status([.carry, .overflow]),
               "TXS should preserve all flags even when transferring negative number")
        
        // Test all flags preserved
        let allFlags = Status([.carry, .zero, .interrupt, .decimal, .break, .overflow, .negative])
        let test3 = testTXSFlags(xRegister: 0x42, initialFlags: allFlags)
        #expect(test3 == allFlags,
               "TXS should preserve all flags")
        
        // Test no flags affected when no flags set
        let test4 = testTXSFlags(xRegister: 0xFF, initialFlags: Status.empty)
        #expect(test4 == Status.empty,
               "TXS should maintain cleared flags")
    }
    
    @Test("TYA - implied mode")
    func TYA_implied() {
        var context = setupImplied(opcode: 0x98)
        context.cpu.registers.indexY = 0x05
        context.expected.a = 0x05
        
        context.cpu.executeNextInstruction()
        verifyCPUState(context: context)
    }
    
    @Test("TYA - Flag behavior")
    func testTYA_flags() {
        func testTYAFlags(yRegister: UInt8) -> (result: UInt8, flags: Status) {
            let context = setupImplied(opcode: 0x98)
            context.cpu.registers.indexY = yRegister
            context.cpu.executeNextInstruction()
            return (context.cpu.registers.accumulator, context.cpu.registers.status)
        }
        
        // Test zero flag when transferring zero
        let test1 = testTYAFlags(yRegister: 0x00)
        #expect(test1.result == 0x00, "Transferring Y=0x00 should store 0x00")
        #expect(test1.flags == Status.zero,
               "Transferring zero should set zero flag")
        
        // Test negative flag when transferring negative number
        let test2 = testTYAFlags(yRegister: 0x80)
        #expect(test2.result == 0x80, "Transferring Y=0x80 should store 0x80")
        #expect(test2.flags == Status.negative,
               "Transferring negative number should set negative flag")
        
        // Test no flags when transferring positive number
        let test3 = testTYAFlags(yRegister: 0x01)
        #expect(test3.result == 0x01, "Transferring Y=0x01 should store 0x01")
        #expect(test3.flags == Status.empty,
               "Transferring positive non-zero number should set no flags")
        
        // Test preserving unaffected flags
        let context = setupImplied(opcode: 0x98)
        context.cpu.registers.indexY = 0x40
        context.cpu.registers.status = Status([.carry, .overflow])
        context.cpu.executeNextInstruction()
        #expect(context.cpu.registers.status == Status([.carry, .overflow]),
               "TYA should preserve carry and overflow flags")
    }
}
