import NESEmulator

typealias Status = NES.CPU.Registers.Status

extension NES.Cartridge {
    class MapperTest: Mapper {
        func read(from address: UInt16) -> UInt8 {
            prgROM[Int(address - prgStart)]
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            prgROM[Int(address - prgStart)] = value
        }
        
        var prgROM: [UInt8]
        var chrROM: [UInt8]
        
        var prgStart: UInt16 = 0x4200
        var prgEnd: UInt16 = 0xFFFF
        
        init(prgROM: [UInt8] = Array(repeating: 0, count: 0xFFFF - 0x4200 + 1), chrROM: [UInt8] = []) {
            self.prgROM = prgROM
            self.chrROM = chrROM
        }
    }
}
