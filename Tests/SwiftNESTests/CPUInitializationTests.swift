import Testing
@testable import SwiftNES

@Suite("CPU Initialization State Tests")
class CPUInitializationTests {
    @Test("Registers have correct initial values")
    func testRegistersState() {
        let mapper = NES.Cartridge.MapperTest()
        
        // Set reset vector to load 0x8000 before NES initialization
        mapper.write(0x00, to: 0xFFFC)
        mapper.write(0x80, to: 0xFFFD)
        
        let nes = NES(cartridge: NES.Cartridge(mapper: mapper))
        let cpu = nes.cpu
        
        // Test initialization
        #expect(cpu.registers.accumulator == 0, "Accumulator should be set to 0 on power up")
        #expect(cpu.registers.indexX == 0, "Index X should be set to 0 on power up")
        #expect(cpu.registers.indexY == 0, "Index Y should be set to 0 on power up")
        #expect(cpu.registers.stackPointer == 0xFD, "Stack pointer should be set to 0xFD on power up")
        #expect(cpu.registers.status == .interrupt, "Status should only contain interrupt flag on power up")
        #expect(cpu.registers.programCounter == 0x8000, "Program counter was not properly pulled from reset vector")
        
        // Simulate arbitrary run time
        
        cpu.registers = NES.CPU.Registers(
            programCounter: 0x9123, accumulator: 0xF0, indexX: 0x10, indexY: 0xFF, stackPointer: 0xD8, processorStatus: .init([.carry, .overflow, .decimal]))
        
        // Test reset
        cpu.reset()
        
        #expect(cpu.registers.accumulator == 0xF0, "Accumulator should not change from reset")
        #expect(cpu.registers.indexX == 0x10, "Index X should not change from reset")
        #expect(cpu.registers.indexY == 0xFF, "Index Y should not change from reset")
        #expect(cpu.registers.stackPointer == 0xD5, "Stack pointer should be decremented by 3 after reset")
        #expect(cpu.registers.status == Status([.carry, .overflow, .decimal, .interrupt]), "Status should include interrupt flag, but otherwise remain the same")
        #expect(cpu.registers.programCounter == 0x8000, "Program counter was not properly pulled from reset vector")
    }
    
    @Test("OAM DMA")
    func testOAMDMA() {
        let nes = NES(cartridge: NES.Cartridge(mapper: NES.Cartridge.MapperTest()))
        let mmu = nes.memoryManager
        let cpu = nes.cpu
        
        // Set PC to 0x8000 on reset/start
        mmu.write(0x00, to: 0xFFFC)
        mmu.write(0x80, to: 0xFFFD)
        
        cpu.reset()
        
        // Insert STA,abs at start of program which writes to 0x4014 (OAM DMA trigger)
        mmu.write(0x8D, to: 0x8000)
        mmu.write(0x14, to: 0x8001)
        mmu.write(0x40, to: 0x8002)
        
        cpu.registers.accumulator = 0x01
        
        let cycles = cpu.executeNextInstruction()
        
        // OAM DMA transfer takes 513-514 cycles on top of whatever write operation was performed to trigger the transfer (STA in this case)
        // 4 cycles for STA absolute
        // +
        // 513 cycles for OAM DMA transfer
        // =
        // 517
        #expect(cycles == 517)
    }
}
