protocol Mapper: Memory {
    var prgROM: [UInt8] { get }
    var chrROM: [UInt8] { get }
    
    var prgStart: UInt16 { get }
    var prgEnd: UInt16 { get }
}

extension Mapper {
    var prgSize: UInt16 {
        prgEnd - prgStart + 1
    }
}

extension NES.Cartridge {
    class Mapper0: Mapper {
        let prgROM: [UInt8]
        let chrROM: [UInt8]
        
        let prgStart: UInt16 = 0x8000
        let prgEnd: UInt16 = 0xFFFF
        
        init(programMemory: [UInt8], characterMemory: [UInt8]) {
            self.prgROM = programMemory
            self.chrROM = characterMemory
        }
        
        func read(from address: UInt16) -> UInt8 {
            switch address {
            case prgStart...prgEnd:
                // PRG ROM - used by the CPU
                // NES assumes 32KB of PRG ROM, but some cartridges only have 16KB
                // If there's less than 32KB, the data gets mirrored to fill all 32KB (0x8000-0xBFFF) == (0xC000-0xFFFF)
                let normalizedAddress = Int(address - 0x8000)
                let mirrorAddress = normalizedAddress % prgROM.count
                return prgROM[mirrorAddress]
            case 0x0000...0x1FFF:
                // CHR ROM - used by the PPU
                return chrROM[Int(address)]
            default:
                // Addresses outside of the defined ranges are typically not used.
                // Returning 0 for simplicity, but error handling could be added.
                print("Mapper0 read from unsupported address: \(address)")
                return 0
            }
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            // Mapper0 doesn't support writing to any RAM
        }
    }
}
