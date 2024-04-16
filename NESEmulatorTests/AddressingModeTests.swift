import XCTest
@testable import NESEmulator

final class AddressingModeTests: XCTestCase {
    var nes: NES?
    
    override func setUpWithError() throws {
        let nes = NES()
        self.nes = nes
        
        // Zero page
        
        nes.memoryManager.write(0xD0, to: 0x0000)
        
        nes.memoryManager.write(0xFC, to: 0x0018)
        nes.memoryManager.write(0x01, to: 0x0019)
        
        nes.memoryManager.write(0x56, to: 0x0020)
        nes.memoryManager.write(0x02, to: 0x0021)
        
        nes.memoryManager.write(0x22, to: 0x0084)
        nes.memoryManager.write(0x04, to: 0x0085)
        
        // Non Zero page
        
        nes.memoryManager.write(0x11, to: 0x01FC)
        
        nes.memoryManager.write(0x1F, to: 0x0200)
        
        nes.memoryManager.write(0x55, to: 0x0256)
        
        nes.memoryManager.write(0x3D, to: 0x02FE)
        
        nes.memoryManager.write(0xFF, to: 0x0421)
        
        nes.memoryManager.write(0xF0, to: 0x0455)
    }
    
    func XCTAssertExpectedClockCycles(expected: UInt8, action: @escaping () -> Void) {
        let preRunCycleCount = nes!.cpu.clockCycleCount
        
        action()
        
        XCTAssertEqual(expected, nes!.cpu.clockCycleCount - preRunCycleCount, "Unexpected clock cycle count")
    }

    func testZeroPageAccess() throws {
        let nes = nes!
        
        nes.cpu.registers.indexX = 0x00
        XCTAssertExpectedClockCycles(expected: 2) {
            let zeropageAddr = nes.cpu.getZeropageAddress(addr: 0x18)
            XCTAssertEqual(nes.memoryManager.read(from: zeropageAddr), 0xFC, "Direct Zero Page access failed")
        }
        
        nes.cpu.registers.indexX = 0x03
        XCTAssertExpectedClockCycles(expected: 3) {
            let zeropageXAddr = nes.cpu.getZeropageXAddress(addr: 0x16)
            XCTAssertEqual(zeropageXAddr, 0x0019)
            XCTAssertEqual(nes.memoryManager.read(from: zeropageXAddr), 0x01, "Zero Page X Indexed access failed")
        }
        
        nes.cpu.registers.indexY = 0x83
        XCTAssertExpectedClockCycles(expected: 3) {
            let zeropageYAddr = nes.cpu.getZeropageYAddress(addr: 0x01)
            XCTAssertEqual(nes.memoryManager.read(from: zeropageYAddr), 0x22, "Zero Page Y Indexed access failed")
        }
        
        nes.cpu.registers.indexX = 0x01
        XCTAssertExpectedClockCycles(expected: 3) {
            let zeropageXWrapAddr = nes.cpu.getZeropageXAddress(addr: 0xFF) // 0xFF + 0x01 should wrap to 0x00
            XCTAssertEqual(nes.memoryManager.read(from: zeropageXWrapAddr), 0xD0)
        }
    }
    
    func testIndexedIndirectAccess() throws {
        let nes = nes!
        
        nes.cpu.registers.indexX = 0x14
        XCTAssertExpectedClockCycles(expected: 5) {
            let indexedIndirectAddress = nes.cpu.getIndexedIndirectAddress(addr: 0x04)
            XCTAssertEqual(indexedIndirectAddress, 0x01FC, "Indexed Indirect (d,x) address was not formatted correctly")
            XCTAssertEqual(nes.memoryManager.read(from: indexedIndirectAddress), 0x11, "Indexed Indirect (d,x) access failed")
        }
    }
    
    func testIndirectIndexedAccess() throws {
        let nes = nes!
        
        nes.cpu.registers.indexY = 0xA8
        XCTAssertExpectedClockCycles(expected: 4) {
            let indirectIndexedAddress = nes.cpu.getIndirectIndexedAddress(addr: 0x20)
            XCTAssertEqual(indirectIndexedAddress, 0x02FE)
            XCTAssertEqual(nes.memoryManager.read(from: indirectIndexedAddress), 0x3D, "Indirect Indexed (d),y access failed")
        }
        
        nes.cpu.registers.indexY = 0x04
        XCTAssertExpectedClockCycles(expected: 5) {
            let indirectIndexedAddress = nes.cpu.getIndirectIndexedAddress(addr: 0x18)
            XCTAssertEqual(indirectIndexedAddress, 0x0200)
            XCTAssertEqual(nes.memoryManager.read(from: indirectIndexedAddress), 0x1F, "Indirect Indexed (d),y access failed")
        }
    }
    
    func testAbsoluteAccess() throws {
        let nes = nes!
        
        XCTAssertExpectedClockCycles(expected: 3) {
            let absoluteAddr = nes.cpu.getAbsoluteAddress(lsb: 0xFC, msb: 0x01)
            XCTAssertEqual(nes.memoryManager.read(from: absoluteAddr), 0x11, "Absolute access failed")
        }
        
        nes.cpu.registers.indexX = 0x56
        XCTAssertExpectedClockCycles(expected: 4) {
            let absoluteXAddr = nes.cpu.getAbsoluteXAddress(lsb: 0x00, msb: 0x02)
            XCTAssertEqual(nes.memoryManager.read(from: absoluteXAddr), 0x55, "Absolute X Indexed access failed")
        }
        
        nes.cpu.registers.indexY = 0xFF
        XCTAssertExpectedClockCycles(expected: 5) {
            let absoluteYAddr = nes.cpu.getAbsoluteYAddress(lsb: 0x01, msb: 0x01)
            XCTAssertEqual(nes.memoryManager.read(from: absoluteYAddr), 0x1F, "Absolute X Indexed access failed")
        }
    }
}
