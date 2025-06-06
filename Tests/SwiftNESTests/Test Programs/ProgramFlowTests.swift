import Testing
import Foundation
@testable import SwiftNES

extension NESRunOption {
    static let test = Self.maxRunCount(.cycles(1_000_000))
}

@Suite("Program Flow Tests")
class ProgramFlowTests {
    enum TestError: Error {
        case fileNotFound
        case couldNotReadFile
    }
    
    func cartridge(forResource resource: String, ofType type: String = "nes") throws -> NES.Cartridge {
        guard let path = Bundle.module.path(forResource: resource, ofType: type) else {
            throw TestError.fileNotFound
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw TestError.couldNotReadFile
        }
        
        return try NES.Cartridge(data: data)
    }
    
    @Test("CPU Dummy Reads")
    func runDummyReads() throws {
        let nes = NES(cartridge: try cartridge(forResource: "cpu_dummy_reads"))
        _ = try nes.run(options: .test)
        
        #expect(Bool(false), "This test plays a sound and displays content on the screen. Remove this expectation once PPU and APU are implemented and test succeeds")
    }
    
    @Test("CPU Branch Tests")
    func runBranchBasics() throws {
        var nes = try NES(cartridge: cartridge(forResource: "branch_basics"))
        _ = try nes.run(options: .test)
        
        nes = try NES(cartridge: cartridge(forResource: "forward_branch"))
        _ = try nes.run(options: .test)
        
        nes = try NES(cartridge: cartridge(forResource: "backward_branch"))
        _ = try nes.run(options: .test)
        
        #expect(Bool(false), "This test plays a sound and displays content on the screen. Remove this expectation once PPU and APU are implemented and test succeeds")
    }
}
