extension NES {
    public class Cartridge: @unchecked Sendable {
        var mapper: Mapper
        
        init(mapper: Mapper) {
            self.mapper = mapper
        }
    }
}

import Foundation

// MARK: - Convenience Initializers

extension NES.Cartridge {
    public convenience init(fileURL: URL) throws {
        try self.init(data: try Data(contentsOf: fileURL))
    }
    
    public convenience init(data: Data) throws {
        let bytes = Array(data)
        
        try self.init(fileData: bytes)
    }
    
    public convenience init(fileData: [UInt8]) throws {
        guard fileData.count > 16 // Header size
        else { throw NESError.cartridge(.invalidHeader(fileData)) }
        
        guard fileData[0] == 0x4E, fileData[1] == 0x45,
              fileData[2] == 0x53, fileData[3] == 0x1A // Expected iNES header identifier
        else { throw NESError.cartridge(.invalidHeader(Array(fileData[0..<16]))) }
        
        let prgSize = Int(fileData[4]) * 16 * 1024 // Number of 16KB PRG-ROM banks
        
        let prgStartIndex = 16 // Starts after header
        let prgEndIndex = prgStartIndex + prgSize
        
        let chrSize = Int(fileData[5]) * 8 * 1024  // Number of 8KB CHR-ROM banks
        
        let chrStartIndex = prgEndIndex
        let chrEndIndex = chrStartIndex + chrSize
        
        // Extract mirroring information from header
        let flags6 = fileData[6]
        let hasFourScreenVRAM = (flags6 & 0x08) != 0
        let verticalMirroring = (flags6 & 0x01) != 0
        
        let mirroringMode: NametableMirroring
        if hasFourScreenVRAM {
            mirroringMode = .fourScreen
        } else if verticalMirroring {
            mirroringMode = .vertical
        } else {
            mirroringMode = .horizontal
        }
        
        self.init(mapper: Mapper0(
            programMemory: Array(fileData[prgStartIndex..<prgEndIndex]),
            characterMemory: Array(fileData[chrStartIndex..<chrEndIndex]),
            mirroringMode: mirroringMode
        ))
    }
}

// MARK: - Convenience Functions

extension NES.Cartridge: Memory {
    public func read(from address: UInt16) -> UInt8 {
        mapper.read(from: address)
    }
    
    public func access(at address: UInt16, modify: (inout UInt8) -> Void) {
        guard address < mapper.prgSize else {
            fatalError("Memory access out of bounds")
        }
        
        modify(&mapper[UInt16(address)])
    }
    
    public func write(_ value: UInt8, to address: UInt16) {
        mapper.write(value, to: address)
    }
}
