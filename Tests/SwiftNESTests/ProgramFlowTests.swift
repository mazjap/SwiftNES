import Testing
import Foundation
@testable import SwiftNES

@Suite("Opcode Flow Tests")
class ProgramFlowTests {
    enum TestError: Error {
        case fileNotFound
        case couldNotReadFile
    }
    
    @Test("CPU Dummy Reads")
    func testRunDummyReads() throws {
        let nes = NES()
        
        guard let path = Bundle.module.path(forResource: "cpu_dummy_reads", ofType: "nes") else {
            throw TestError.fileNotFound
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw TestError.couldNotReadFile
        }
        
        let mapper = NES.Cartridge.MapperTest()
        
        nes.memoryManager.cartridge = NES.Cartridge(mapper: mapper)
        nes.cpu.registers.programCounter = 0x8000
        
        // TODO: - write file to entire memory - perhaps there's a mapper mode at the beginning of the file, I need to look into this deeper
//        try nes.run()
    }
}
