import XCTest
@testable import NESEmulator

final class CPUInitializationTests: XCTestCase {
    var nes: NES?
    
    override func setUpWithError() throws {
        let nes = NES()
        
        self.nes = nes
    }
    
    func testRegistersState() {
        let cpu = nes!.cpu
        
        XCTAssertEqual(cpu.registers.accumulator, 0, "Accumulator was not properly initialized")
        XCTAssertEqual(cpu.registers.indexX, 0, "Index X was not properly initialized")
        XCTAssertEqual(cpu.registers.indexY, 0, "Index Y was not properly initialized")
        XCTAssertEqual(cpu.registers.stackPointer, 0xFD, "Stack pointer was not properly initialized")
        XCTAssertEqual(cpu.registers.programCounter, 0xFFFC, "Program counter was not properly initialized")
    }
}
