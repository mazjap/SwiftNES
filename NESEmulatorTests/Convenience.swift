import NESEmulator

typealias Status = NES.CPU.Registers.Status

extension NES.Cartridge {
    class MapperTest: Mapper {
        func read(from address: UInt16) -> UInt8 {
            guard address >= prgStart && address <= prgEnd else {
                fatalError("Address out of bounds")
            }
            
            return prgROM[Int(address - prgStart)]
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            guard address >= prgStart && address <= prgEnd else {
                fatalError("Address out of bounds")
            }
            
            prgROM[Int(address - prgStart)] = value
        }
        
        var prgROM: [UInt8]
        var chrROM: [UInt8]
        
        var prgStart: UInt16 = 0x4020
        var prgEnd: UInt16
        
        init(prgRomSize: UInt16 = 0xBFDF) {
            self.prgEnd = prgStart + prgRomSize
            self.prgROM = Array(repeating: 0, count: Int(prgRomSize) + 1)
            self.chrROM = []
        }
    }
}
