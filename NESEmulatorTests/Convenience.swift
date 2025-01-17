@testable import NESEmulator

typealias Status = NES.CPU.Registers.Status

extension NES.Cartridge {
    class MapperTest: Mapper {
        func read(from address: UInt16) -> UInt8 {
            guard address >= prgStart && address <= prgEnd else {
                fatalError("Address out of bounds")
            }
            
            return prgROM[Int(address - prgStart)]
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            guard address >= prgStart && address <= prgEnd else {
                fatalError("Address out of bounds")
            }
            
            prgROM[Int(address - prgStart)] = value
        }
        
        var prgROM: [UInt8]
        var chrROM: [UInt8]
        
        var prgStart: UInt16 = 0x4020
        var prgEnd: UInt16
        
        init(prgRomSize: UInt16 = 0xBFDF) {
            self.prgEnd = prgStart + prgRomSize
            self.prgROM = Array(repeating: 0, count: Int(prgRomSize) + 1)
            self.chrROM = []
        }
    }
}

extension NES.CPU {
    convenience init(memoryManager: NES.MMU, registers: Registers, clockCycleCount: UInt8) {
        self.init(memoryManager: memoryManager)
        self.registers = registers
        self.clockCycleCount = clockCycleCount
    }
}

extension NES.MMU {
    convenience init(usingTestMapper: Bool) {
        self.init(cartridge: .init(mapper: NES.Cartridge.MapperTest()))
    }
}

class TestBase {
    /// Creates a fresh CPU and MMU for each test
    func createTestCPU(atAddress: UInt16 = 0x8000) -> (cpu: NES.CPU, mmu: NES.MMU) {
        let nes = NES(cartridge: NES.Cartridge(mapper: NES.Cartridge.MapperTest()))
        nes.cpu.registers.status = .empty
        nes.cpu.registers.programCounter = atAddress
        
        return (nes.cpu, nes.memoryManager)
    }
}

/// Test context holding CPU state for a single test
struct CPUTestContext {
    let cpu: NES.CPU
    let mmu: NES.MMU
    let initialPC: UInt16
    var expected: ExpectedState
    
    /// Uses the cpu's current stack pointer to check the current stack item offset by 1 + `back`
    /// - Parameter back: The offset to apply to the current stack pointer. Defaults to 0
    /// If the stack is [0, 5, 6, 7], where index 0 is the location of the stack pointer:
    /// - back=0 results in 5
    /// - back=1 results in 6
    /// - back=2 results in 7
    func checkStack(back: UInt16 = 0) -> UInt8 {
        mmu.read(from: 0x0100 + UInt16(cpu.registers.stackPointer) + back + 1)
    }
}
