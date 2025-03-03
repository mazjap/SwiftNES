import Testing
@testable import SwiftNES

enum PCStatus {
    case relative(Int16)
    case absolute(UInt16)
}

/// Represents the expected outcome of a CPU operation
struct ExpectedState {
    var cycles: UInt16
    var pcStatus: PCStatus
    var a: UInt8?
    var x: UInt8?
    var y: UInt8?
    var sp: UInt8?
    var status: Status?
    
    init(cycles: UInt16, pcStatus: PCStatus, absolutePC: UInt16? = nil, a: UInt8? = nil, x: UInt8? = nil, y: UInt8? = nil, sp: UInt8? = nil, status: Status? = nil) {
        self.cycles = cycles
        self.pcStatus = pcStatus
        self.a = a
        self.x = x
        self.y = y
        self.sp = sp
        self.status = status
    }
}

extension ExpectedState {
    init(cycles: UInt16, pcIncrement: Int16, a: UInt8? = nil, x: UInt8? = nil, y: UInt8? = nil, sp: UInt8? = nil, status: Status? = nil) {
        self.init(cycles: cycles, pcStatus: .relative(pcIncrement), a: a, x: x, y: y, sp: sp, status: status)
    }
}

/// Base class providing CPU test functionality
class OpcodeTestBase: TestBase {
    // Helper to get timing info for a specific opcode
    func getInstructionTiming(opcode: UInt8, pageCrossed: Bool = false, branchTaken: Bool = false) -> UInt16 {
        guard let timing = NES.CPU.instructionTimings[opcode] else {
            fatalError("Unknown opcode: \(String(opcode, radix: 16))")
        }
        
        var cycles = timing.baseCycles
        if timing.addPageCross && pageCrossed {
            cycles += 1
        }
        if timing.addSuccessfulBranch && branchTaken {
            cycles += 1
        }
        return cycles
    }
    
    // MARK: - Addressing Mode Setup Functions
    
    /// Sets up immediate mode addressing
    /// Example: LDA #$44 (A9 44)
    func setupImmediate(opcode: UInt8, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(value, to: atAddress + 1)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 2
            )
        )
    }
    
    /// Sets up zero page addressing
    /// Example: LDA $44 (A5 44)
    func setupZeroPage(opcode: UInt8, zeroPageAddress: UInt8, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(zeroPageAddress, to: atAddress + 1)
        nes.memoryManager.write(value, to: UInt16(zeroPageAddress))
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 2
            )
        )
    }
    
    /// Sets up zero page,X addressing
    /// Example: LDA $44,X (B5 44)
    func setupZeroPageX(opcode: UInt8, zeroPageAddress: UInt8, xOffset: UInt8, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(zeroPageAddress, to: atAddress + 1)
        nes.memoryManager.write(value, to: UInt16((zeroPageAddress &+ xOffset) & 0xFF))
        nes.cpu.registers.indexX = xOffset
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 2
            )
        )
    }
    
    /// Sets up zero page,Y addressing
    /// Example: LDX $44,Y (B6 44)
    func setupZeroPageY(opcode: UInt8, zeroPageAddress: UInt8, yOffset: UInt8, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(zeroPageAddress, to: atAddress + 1)
        nes.memoryManager.write(value, to: UInt16((zeroPageAddress &+ yOffset) & 0xFF))
        nes.cpu.registers.indexY = yOffset
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 2
            )
        )
    }
    
    /// Sets up absolute addressing
    /// Example: LDA $4400 (AD 00 44)
    func setupAbsolute(opcode: UInt8, absoluteAddress: UInt16, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(UInt8(absoluteAddress & 0xFF), to: atAddress + 1)
        nes.memoryManager.write(UInt8(absoluteAddress >> 8), to: atAddress + 2)
        nes.memoryManager.write(value, to: absoluteAddress)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 3
            )
        )
    }
    
    /// Sets up absolute,X addressing
    /// Example: LDA $4400,X (BD 00 44)
    func setupAbsoluteX(opcode: UInt8, absoluteAddress: UInt16, xOffset: UInt8, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(UInt8(absoluteAddress & 0xFF), to: atAddress + 1)
        nes.memoryManager.write(UInt8(absoluteAddress >> 8), to: atAddress + 2)
        nes.memoryManager.write(value, to: absoluteAddress &+ UInt16(xOffset))
        nes.cpu.registers.indexX = xOffset
        
        // Check if page boundary is crossed
        let pageCrossed = (absoluteAddress & 0xFF00) != ((absoluteAddress &+ UInt16(xOffset)) & 0xFF00)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode, pageCrossed: pageCrossed),
                pcIncrement: 3
            )
        )
    }
    
    /// Sets up absolute,Y addressing
    /// Example: LDA $4400,Y (B9 00 44)
    func setupAbsoluteY(opcode: UInt8, absoluteAddress: UInt16, yOffset: UInt8, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(UInt8(absoluteAddress & 0xFF), to: atAddress + 1)
        nes.memoryManager.write(UInt8(absoluteAddress >> 8), to: atAddress + 2)
        nes.memoryManager.write(value, to: absoluteAddress &+ UInt16(yOffset))
        nes.cpu.registers.indexY = yOffset
        
        // Check if page boundary is crossed
        let pageCrossed = (absoluteAddress & 0xFF00) != ((absoluteAddress &+ UInt16(yOffset)) & 0xFF00)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode, pageCrossed: pageCrossed),
                pcIncrement: 3
            )
        )
    }
    
    /// (indirect,X) - Example: LDA ($44,X)
    /// First adds X to zero-page address, then gets target from that location
    func setupIndexedIndirect(opcode: UInt8, zeroPageAddress: UInt8, xOffset: UInt8, targetAddress: UInt16, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(zeroPageAddress, to: atAddress + 1)
        
        let effectiveZPAddress = (zeroPageAddress &+ xOffset) & 0xFF
        nes.memoryManager.write(UInt8(targetAddress & 0xFF), to: UInt16(effectiveZPAddress))
        nes.memoryManager.write(UInt8(targetAddress >> 8), to: UInt16(effectiveZPAddress &+ 1))
        nes.memoryManager.write(value, to: targetAddress)
        nes.cpu.registers.indexX = xOffset
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 2
            )
        )
    }
    
    /// (indirect),Y - Example: LDA ($44),Y
    /// First gets base address from zero-page, then adds Y to target
    func setupIndirectIndexed(opcode: UInt8, zeroPageAddress: UInt8, yOffset: UInt8, targetAddress: UInt16, value: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(zeroPageAddress, to: atAddress + 1)
        
        nes.memoryManager.write(UInt8(targetAddress & 0xFF), to: UInt16(zeroPageAddress))
        nes.memoryManager.write(UInt8(targetAddress >> 8), to: UInt16(zeroPageAddress &+ 1))
        nes.memoryManager.write(value, to: targetAddress &+ UInt16(yOffset))
        nes.cpu.registers.indexY = yOffset
        
        // Check if page boundary is crossed
        let pageCrossed = (targetAddress & 0xFF00) != ((targetAddress &+ UInt16(yOffset)) & 0xFF00)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode, pageCrossed: pageCrossed),
                pcIncrement: 2
            )
        )
    }
    
    /// Sets up indirect addressing (JMP only)
    /// Example: JMP ($4400) (6C 00 44)
    func setupIndirect(opcode: UInt8, indirectAddress: UInt16, targetAddress: UInt16, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(UInt8(indirectAddress & 0xFF), to: atAddress + 1)
        nes.memoryManager.write(UInt8(indirectAddress >> 8), to: atAddress + 2)
        
        // Write low byte at the indirect address
        nes.memoryManager.write(UInt8(targetAddress & 0xFF), to: indirectAddress)
        
        // Handle 6502 indirect jump bug when address is at page boundary
        let highByteAddr = if (indirectAddress & 0xFF) == 0xFF {
            indirectAddress & 0xFF00  // Read from start of same page instead of crossing
        } else {
            indirectAddress + 1
        }
        nes.memoryManager.write(UInt8(targetAddress >> 8), to: highByteAddr)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 0 // JMP replaces PC instead of incrementing
            )
        )
    }
    
    /// Sets up implied addressing (no operands)
    /// Example: TAX (AA)
    func setupImplied(opcode: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 1
            )
        )
    }
    
    /// Sets up relative addressing (for branch instructions)
    /// Example: BNE $44 (D0 44)
    func setupRelative(opcode: UInt8, offset: Int8, atAddress: UInt16 = 0x8000, branchTaken: Bool) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        nes.memoryManager.write(UInt8(bitPattern: offset), to: atAddress + 1)
        
        // The pcIncrement should be conditional on branchTaken
        let operationIncrements: Int16 = 2
        let offset = branchTaken ? Int16(offset) : 0
        
        let pageCrossed = (atAddress & 0xFF00) != (UInt16(bitPattern: Int16(bitPattern: atAddress) &+ operationIncrements &+ offset) & 0xFF00)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode, pageCrossed: pageCrossed, branchTaken: branchTaken),
                pcIncrement: offset + operationIncrements
            )
        )
    }
    
    /// Sets up accumulator addressing (for operations that work on accumulator)
    /// Example: LSR A (4A)
    func setupAccumulator(opcode: UInt8, atAddress: UInt16 = 0x8000) -> CPUTestContext {
        let nes = createTestNES(withPcAtAddress: atAddress)
        
        nes.memoryManager.write(opcode, to: atAddress)
        
        return CPUTestContext(
            nes: nes,
            initialPC: atAddress,
            expected: ExpectedState(
                cycles: getInstructionTiming(opcode: opcode),
                pcIncrement: 1
            )
        )
    }
    
    // MARK: - Verification Helper
    
    /// Verifies the CPU state matches expected values
    func verifyCPUState(context: CPUTestContext, message: String = "", fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) {
        let callerLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
        let expected = context.expected
        let cpu = context.cpu
        let initialPC = context.initialPC
        let messageContext = message.isEmpty ? "" : " (\(message))"
        
        #expect(cpu.clockCycleCount == expected.cycles,
               "Expected \(expected.cycles) cycles, got \(cpu.clockCycleCount)\(messageContext)",
                sourceLocation: callerLocation)
        
        switch expected.pcStatus {
        case let .relative(pcIncrement):
            #expect(cpu.registers.programCounter == UInt16(bitPattern: Int16(bitPattern: initialPC) &+ pcIncrement),
                   "Expected PC to advance by \(pcIncrement)\(messageContext)",
                   sourceLocation: callerLocation)
        case let .absolute(absolutePC):
            #expect(cpu.registers.programCounter == absolutePC,
                   "Expected PC=\(String(absolutePC, radix: 16)), got \(String(cpu.registers.programCounter, radix: 16))\(messageContext)",
                   sourceLocation: callerLocation)
        }
        
        if let a = expected.a {
            #expect(cpu.registers.accumulator == a,
                   "Expected A=\(String(a, radix: 16)), got \(String(cpu.registers.accumulator, radix: 16))\(messageContext)",
                    sourceLocation: callerLocation)
        }
        
        if let x = expected.x {
            #expect(cpu.registers.indexX == x,
                   "Expected X=\(String(x, radix: 16)), got \(String(cpu.registers.indexX, radix: 16))\(messageContext)",
                    sourceLocation: callerLocation)
        }
        
        if let y = expected.y {
            #expect(cpu.registers.indexY == y,
                   "Expected Y=\(String(y, radix: 16)), got \(String(cpu.registers.indexY, radix: 16))\(messageContext)",
                    sourceLocation: callerLocation)
        }
        
        if let sp = expected.sp {
            #expect(cpu.registers.stackPointer == sp,
                   "Expected SP=\(String(sp, radix: 16)), got \(String(cpu.registers.stackPointer, radix: 16))\(messageContext)",
                    sourceLocation: callerLocation)
        }
        
        if let status = expected.status {
            #expect(cpu.registers.status.rawValue == status.rawValue,
                   "Expected status=\(String(status.rawValue, radix: 2)), got \(String(cpu.registers.status.rawValue, radix: 2))\(messageContext)",
                    sourceLocation: callerLocation)
        }
    }
}
