import SwiftNES
import Testing

@Suite("CPU Memory Management Tests")
class MemoryManagementTests {
    
    // MARK: - RAM Mirroring

    @Test("Single write affects all mirrors")
    func testBasicMirroring() {
        let mmu = NES.MMU(usingTestMapper: true)
        
        mmu.write(0xFF, to: 0x0200)
        
        // Check each mirror 0x200 + (0x800 * n) up to 0x1FFF
        #expect(mmu.read(from: 0x0200) == 0xFF) // n = 0
        #expect(mmu.read(from: 0x0A00) == 0xFF) // n = 1
        #expect(mmu.read(from: 0x1200) == 0xFF) // n = 2
        #expect(mmu.read(from: 0x1A00) == 0xFF) // n = 3
    }

    @Test("Writing to different mirrors affects all mirrors")
    func testMirrorWriteVariations() {
        let mmu = NES.MMU(usingTestMapper: true)
        
        // Write to each mirror and verify all mirrors update
        mmu.write(0xFF, to: 0x0200)  // First mirror
        #expect(mmu.read(from: 0x0A00) == 0xFF)
        
        mmu.write(0xEE, to: 0x0A00)  // Second mirror
        #expect(mmu.read(from: 0x0200) == 0xEE)
        
        mmu.write(0xDD, to: 0x1200)  // Third mirror
        #expect(mmu.read(from: 0x0200) == 0xDD)
        
        mmu.write(0xCC, to: 0x1A00)  // Fourth mirror
        #expect(mmu.read(from: 0x0200) == 0xCC)
    }

    @Test("Writing at start/end of mirror regions")
    func testMirrorBoundaries() {
        let mmu = NES.MMU(usingTestMapper: true)
        
        // Test first byte of each mirror
        mmu.write(0xAA, to: 0x0000)
        #expect(mmu.read(from: 0x0800) == 0xAA)
        #expect(mmu.read(from: 0x1000) == 0xAA)
        #expect(mmu.read(from: 0x1800) == 0xAA)
        
        // Test last byte of each mirror
        mmu.write(0xBB, to: 0x07FF)
        #expect(mmu.read(from: 0x0FFF) == 0xBB)
        #expect(mmu.read(from: 0x17FF) == 0xBB)
        #expect(mmu.read(from: 0x1FFF) == 0xBB)
    }

    @Test("Reading/writing across mirror boundaries")
    func testCrossMirrorOperations() {
        let mmu = NES.MMU(usingTestMapper: true)
        
        // Write a pattern across mirror boundary
        for i in 0..<16 {
            mmu.write(UInt8(i), to: 0x07F8 + UInt16(i))
        }
        
        // Verify pattern wraps correctly
        for i in 0..<8 {
            #expect(mmu.read(from: 0x07F8 + UInt16(i)) == UInt8(i))
            #expect(mmu.read(from: 0x0000 + UInt16(i)) == UInt8(i + 8))
        }
    }

    @Test("RAM mirrors don't affect other memory regions")
    func testMirrorToRegionIsolation() {
        let mmu = NES.MMU(usingTestMapper: true)
        
        // Write pattern to first mirror
        mmu.write(0xAA, to: 0x0200)
        
        // Check regions just outside mirror boundaries
        #expect(mmu.read(from: 0x2000) != 0xAA, "PPU registers should not be affected")
        #expect(mmu.read(from: 0x4000) != 0xAA, "APU registers should not be affected")
        #expect(mmu.read(from: 0x4020) != 0xAA, "Cartridge space should not be affected")
        
        // Write to non-mirrored regions shouldn't affect RAM
        mmu.write(0xBB, to: 0x2000)
        #expect(mmu.read(from: 0x0200) == 0xAA, "Writing to PPU registers shouldn't affect RAM")
    }

    @Test("Memory regions are properly isolated")
    func testRegionIsolation() {
        let nes = NES(cartridge: .init(mapper: NES.Cartridge.MapperTest()))
        let mmu = nes.memoryManager
        // TODO: - Implement APU and IO + their memory mappings for this to pass
        
        // Write near region boundaries
        mmu.write(0x42, to: 0x1FFF) // End of RAM mirrors
        mmu.write(0x43, to: 0x2000) // Start of PPU registers
        mmu.write(0x44, to: 0x3FFF) // End of PPU registers
        mmu.write(0x45, to: 0x4000) // Start of APU registers
        
        // Verify each region is isolated
        #expect(mmu.read(from: 0x1FFF) == 0x42)
        #expect(mmu.read(from: 0x2000) == 0x43)
        #expect(mmu.read(from: 0x3FFF) == 0x44)
        #expect(mmu.read(from: 0x4000) == 0x45)
    }
    
    // MARK: - PPU Register Mapping
    
    @Test("PPU register mirroring behavior")
    func testPPURegisterMirroring() {
        let nes = NES(cartridge: .init(mapper: NES.Cartridge.MapperTest()))
        let mmu = nes.memoryManager
        
        // PPU has 8 registers (0x2000-0x2007) mirrored every 8 bytes up to 0x3FFF
        mmu.write(0x42, to: 0x2000)  // PPUCTRL
        
        // Should be mirrored every 8 bytes
        #expect(mmu.read(from: 0x2008) == 0x42) // First mirror
        #expect(mmu.read(from: 0x2010) == 0x42) // Second mirror
        #expect(mmu.read(from: 0x3FF8) == 0x42) // Last mirror
    }

    @Test("PPU register individual access")
    func testPPURegisterAccess() {
        let nes = NES(cartridge: .init(mapper: NES.Cartridge.MapperTest()))
        let mmu = nes.memoryManager
        
        // TODO: - Add all PPU registers
        mmu.write(0x42, to: 0x2000) // PPUCTRL
        mmu.write(0x43, to: 0x2001) // PPUMASK
        mmu.write(0x44, to: 0x2002) // PPUSTATUS - Write should have no effect
        // ... etc
        
        #expect(mmu.read(from: 0x2000) == 0x42)
        #expect(mmu.read(from: 0x2001) == 0x43)
        #expect(mmu.read(from: 0x2002) != 0x44) // PPUSTATUS (0x2002) is read-only
    }
    
    // MARK: - APU Register Mapping
    
    @Test("APU register access")
    func testAPURegisterAccess() {
        let nes = NES(cartridge: .init(mapper: NES.Cartridge.MapperTest()))
        let mmu = nes.memoryManager
        
        // TODO: - Add all APU registers
        mmu.write(0x42, to: 0x4000) // Pulse 1 duty
        mmu.write(0x43, to: 0x4001) // Pulse 1 sweep
        // ... etc
        
        #expect(mmu.read(from: 0x4000) == 0x42)
        #expect(mmu.read(from: 0x4001) == 0x43)
    }
    
    // MARK: - IO Register Mapping

    @Test("I/O register access")
    func testIORegisterAccess() {
        let nes = NES(cartridge: .init(mapper: NES.Cartridge.MapperTest()))
        let mmu = nes.memoryManager
        
        // Test controller ports
        mmu.write(0x42, to: 0x4016) // Controller 1
        mmu.write(0x43, to: 0x4017) // Controller 2
        
        #expect(mmu.read(from: 0x4016) == 0x42)
        #expect(mmu.read(from: 0x4017) == 0x43)
    }
    
    // MARK: - Cartridge Mapping
    
    @Test("Basic cartridge space access")
    func testCartridgeSpaceAccess() {
        let mmu = NES.MMU(usingTestMapper: true)
        
        // Test basic read/write to cartridge space (0x4020-0xFFFF)
        mmu.write(0x42, to: 0x4020)
        mmu.write(0x42, to: 0xFFFF)
        
        #expect(mmu.read(from: 0x4020) == 0x42, "Should be able to read from cartridge space")
        #expect(mmu.read(from: 0xFFFF) == 0x42, "Should be able to access end of cartridge space")
    }

    @Test("Cartridge space boundaries")
    func testCartridgeSpaceBoundaries() {
        let nes = NES(cartridge: .init(mapper: NES.Cartridge.MapperTest()))
        let mmu = nes.memoryManager
        
        // Write at boundaries between APU/IO and cartridge space
        mmu.write(0x42, to: 0x4017) // Last APU register
        mmu.write(0x43, to: 0x4020) // First cartridge address
        
        
        #expect(mmu.read(from: 0x4017) == 0x42, "APU register access should work")
        #expect(mmu.read(from: 0x4020) == 0x43, "Cartridge access should work")
    }

    @Test("Missing cartridge handling")
    func testMissingCartridge() {
        let mmu = NES.MMU() // No cartridge
        
        // Writing to cartridge space with no cartridge should have no effect
        mmu.write(0xFF, to: 0x4020)
        mmu.write(0x42, to: 0xFFFF)
        // Reading from cartridge space with no cartridge should return a default value
        let beginningOfCartridgeSpace = mmu.read(from: 0x4020)
        let endOfCartridgeSpace = mmu.read(from: 0xFFFF)
        #expect(beginningOfCartridgeSpace == 0, "Reading with no cartridge should return 0")
        #expect(endOfCartridgeSpace == 0, "Reading with no cartridge should return 0")
    }
}
