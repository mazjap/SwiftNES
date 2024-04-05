import XCTest
@testable import NESEmulator

final class AddressingModeTests: XCTestCase {
    var nes: NES?
    
    override func setUpWithError() throws {
        let nes = NES()
        nes.cpu = NES.CPU(memory: .init(size: 0xFFFF))
        self.nes = nes
        
        // Zero page
        
        nes.cpu.memory.write(0x25, to: 0x0004)
        
        nes.cpu.memory.write(0xFF, to: 0x0018)
        nes.cpu.memory.write(0x24, to: 0x0019)
        
        nes.cpu.memory.write(0xEE, to: 0x0054)
        nes.cpu.memory.write(0x24, to: 0x0055)
        
        nes.cpu.memory.write(0x56, to: 0x00F2)
        
        nes.cpu.memory.write(0xD3, to: 0x0000)
        
        // Non Zero page
        
        nes.cpu.memory.write(0xBE, to: 0x0100)
        
        nes.cpu.memory.write(0x1D, to: 0x24FF)
        
        nes.cpu.memory.write(0x33, to: 0x25FE)
        
        nes.cpu.memory.write(0x05, to: 0x5872)
    }
    
    func XCTAssertExpectedClockCycles(expected: UInt8, action: @escaping () -> Void) {
        let preRunCycleCount = nes!.cpu.clockCycleCount
        
        action()
        
        XCTAssertEqual(expected, nes!.cpu.clockCycleCount - preRunCycleCount, "Unexpected clock cycle count")
    }

    func testZeroPageAccess() throws {
        let nes = nes!
        
        XCTAssertExpectedClockCycles(expected: 2) {
            let zeropageAddr = nes.cpu.getZeropageAddress(addr: 0x04)
            XCTAssertEqual(nes.cpu.memory.read(from: zeropageAddr), 0x25, "Direct Zero Page access failed")
        }
        
        XCTAssertExpectedClockCycles(expected: 3) {
            nes.cpu.registers.indexX = 0x02
            let zeropageXAddr = nes.cpu.getZeropageXAddress(addr: 0x16)
            XCTAssertEqual(nes.cpu.memory.read(from: zeropageXAddr), 0xFF, "Zero Page X Indexed access failed")
        }
        
        nes.cpu.registers.indexY = 0xF1
        XCTAssertExpectedClockCycles(expected: 3) {
            let zeropageYAddr = nes.cpu.getZeropageYAddress(addr: 0x01)
            XCTAssertEqual(nes.cpu.memory.read(from: zeropageYAddr), 0x56, "Zero Page Y Indexed access failed")
        }
        
        nes.cpu.registers.indexX = 0x01
        XCTAssertExpectedClockCycles(expected: 3) {
            let zeropageXWrapAddr = nes.cpu.getZeropageXAddress(addr: 0xFF) // 0xFF + 0x01 should wrap to 0x00
            XCTAssertEqual(nes.cpu.memory.read(from: zeropageXWrapAddr), 0xD3)
        }
    }
    
    func testIndexedIndirect() throws {
        let nes = nes!
        
        nes.cpu.registers.indexX = 0x14
        XCTAssertExpectedClockCycles(expected: 5) {
            let indexedIndirectAddress = nes.cpu.getIndexedIndirectAddress(addr: 0x04)
            XCTAssertEqual(indexedIndirectAddress, 0x24FF, "Indexed Indirect (d,x) address was not formatted correctly")
            XCTAssertEqual(nes.cpu.memory.read(from: indexedIndirectAddress), 0x1D, "Indexed Indirect (d,x) access failed")
        }
    }
    
    func testIndirectIndexed() throws {
        let nes = nes!
        
        nes.cpu.registers.indexY = 0x11
        XCTAssertExpectedClockCycles(expected: 4) {
            let indirectIndexedAddress = nes.cpu.getIndirectIndexedAddress(addr: 0x54)
            XCTAssertEqual(nes.cpu.memory.read(from: indirectIndexedAddress), 0x1D, "Indirect Indexed (d),y access failed")
        }
        
        nes.cpu.registers.indexY = 0xFF
        XCTAssertExpectedClockCycles(expected: 5) {
            let indirectIndexedAddress = nes.cpu.getIndirectIndexedAddress(addr: 0x18)
            XCTAssertEqual(nes.cpu.memory.read(from: indirectIndexedAddress), 0x33, "Indirect Indexed (d),y access failed")
        }
    }
    
    func testAbsoluteAccess() throws {
        let nes = nes!
        
        XCTAssertExpectedClockCycles(expected: 3) {
            let absoluteAddr = nes.cpu.getAbsoluteAddress(lsb: 0x00, msb: 0x01)
            XCTAssertEqual(nes.cpu.memory.read(from: absoluteAddr), 0xBE, "Absolute access failed")
        }
        
        nes.cpu.registers.indexX = 0xAB
        XCTAssertExpectedClockCycles(expected: 4) {
            let absoluteXAddr = nes.cpu.getAbsoluteXAddress(lsb: 0x54, msb: 0x24)
            XCTAssertEqual(nes.cpu.memory.read(from: absoluteXAddr), 0x1D, "Absolute X Indexed access failed")
        }
        
        nes.cpu.registers.indexY = 0xFF
        XCTAssertExpectedClockCycles(expected: 5) {
            let absoluteYAddr = nes.cpu.getAbsoluteYAddress(lsb: 0x73, msb: 0x57)
            XCTAssertEqual(nes.cpu.memory.read(from: absoluteYAddr), 0x05, "Absolute X Indexed access failed")
        }
    }
}
