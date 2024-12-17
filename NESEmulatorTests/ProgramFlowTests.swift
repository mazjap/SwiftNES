import Testing
import Foundation
import NESEmulator

@Suite("Opcode Flow Tests")
class ProgramFlowTests {
    @Test("CPU Dummy Reads")
    func testRunDummyReads() throws {
        let nes = NES()
        
        guard let path = Bundle(for: Self.self).path(forResource: "cpu_dummy_reads", ofType: "nes") else {
            throw NSError(domain: "Tests", code: 1)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw NSError(domain: "Tests", code: 2)
        }
        
        let mapper = NES.Cartridge.MapperTest()
        
        nes.memoryManager.cartridge = NES.Cartridge(mapper: mapper)
        nes.cpu.registers.programCounter = 0x8000
        
        // TODO: - write file to entire memory - perhaps there's a mapper mode at the beginning of the file, I need to look into this deeper
//        try nes.run()
    }
}
