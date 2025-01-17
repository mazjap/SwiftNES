import Testing
import NESEmulator

@Suite("CPU Initialization State Tests")
class CPUInitializationTests {
    func testInitialization(cpu: NES.CPU, fileID: String = #fileID, filePath: String = #filePath, line: Int = #line, column: Int = #column) {
        let callerLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
        
        #expect(
            cpu.registers.accumulator == 0,
            "Accumulator should be set to 0 on reset/power up",
            sourceLocation: callerLocation
        )
        #expect(
            cpu.registers.indexX == 0,
            "Index X should be set to 0 on reset/power up",
            sourceLocation: callerLocation
        )
        #expect(
            cpu.registers.indexY == 0,
            "Index Y should be set to 0 on reset/power up",
            sourceLocation: callerLocation
        )
        #expect(
            cpu.registers.stackPointer == 0xFD,
            "Stack pointer should be set to 0xFD on reset/power up",
            sourceLocation: callerLocation
        )
        #expect(
            cpu.registers.status == .interrupt,
            "Status should only contain interrupt flag on reset/power up",
            sourceLocation: callerLocation
        )
        #expect(
            cpu.registers.programCounter == 0x8000,
            "Program counter was not properly pulled from reset vector",
            sourceLocation: callerLocation
        )
    }
    
    @Test("Registers have correct initial values")
    func testRegistersState() {
        // Test initialization
        let mmu = NES.MMU(usingTestMapper: true)
        
        // Set reset vector to load 0x8000
        mmu.write(0x00, to: 0xFFFC)
        mmu.write(0x80, to: 0xFFFD)
        
        let cpu = NES.CPU(memoryManager: mmu)
        
        
        testInitialization(cpu: cpu)
        
        // Test reset
        cpu.reset()
        testInitialization(cpu: cpu)
    }
}
