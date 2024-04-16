extension NES {
    class Cartridge {
        let mapper: Mapper
        
        init(mapper: Mapper) {
            self.mapper = mapper
        }
    }
}

import Foundation

// MARK: - Convenience Initializers

extension NES.Cartridge {
    convenience init(fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        var bytes = [UInt8](repeating: 0, count: data.count)

        data.withUnsafeBytes { rawBufferPointer in
            let bufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
            for i in 0..<data.count {
                bytes[i] = bufferPointer[i]
            }
        }
        
        try self.init(fileData: bytes)
    }
    
    convenience init(fileData: [UInt8]) throws {
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
        
        self.init(mapper: Mapper0(programMemory: Array(fileData[prgStartIndex..<prgEndIndex]), characterMemory: Array(fileData[chrStartIndex...chrEndIndex])))
    }
}

// MARK: - Convenience Functions

extension NES.Cartridge: Memory {
    func read(from address: UInt16) -> UInt8 {
        mapper.read(from: address)
    }
    
    func write(_ value: UInt8, to address: UInt16) {
        mapper.write(value, to: address)
    }
}
