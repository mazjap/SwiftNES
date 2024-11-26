import Testing
@testable import NESEmulator

@Suite("CPU Initialization State Tests")
class CPUInitializationTests {
    @Test("Registers have correct initial values")
    func testRegistersState() {
        let cpu = NES().cpu
        
        #expect(cpu.registers.accumulator == 0, "Accumulator was not properly initialized")
        #expect(cpu.registers.indexX == 0, "Index X was not properly initialized")
        #expect(cpu.registers.indexY == 0, "Index Y was not properly initialized")
        #expect(cpu.registers.stackPointer == 0xFD, "Stack pointer was not properly initialized")
        #expect(cpu.registers.programCounter == 0xFFFC, "Program counter was not properly initialized")
    }
}
