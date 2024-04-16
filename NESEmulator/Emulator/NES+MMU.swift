extension NES {
    class MMU: Memory {
        var internalRAM: RandomAccessMemory
        var cartridge: Cartridge?
        
        init(internalRAM: RandomAccessMemory = .init(), cartridge: Cartridge? = nil) {
            self.internalRAM = internalRAM
            self.cartridge = cartridge
        }
        
        func read(from address: UInt16) -> UInt8 {
            switch address {
            case 0x0000...0x1FFF:
                // Internal RAM and its mirrors
                internalRAM.read(from: address & 0x07FF)
            case 0x2000...0x3FFF:
                // TODO: - Retreive from PPU registers (only 8 bytes, subsequent bytes are mirrored)
                0
            case 0x4000...0x4017:
                // TODO: - Retreive from APU and IO registers
                0
            case 0x4018...0x401F:
                // APU and IO functionality that is normally disabled
                0
            case 0x4020...0xFFFF:
                // Handled by Cartridges mapper
                cartridge?.read(from: address) ?? 0
            default:
                // Switch cases are exhaustive, but swift doesn't check for types that aren't enum, tuple, or the specific Bool struct (https://forums.swift.org/t/switch-on-int-with-exhaustive-cases-still-needs-default/49548)
                fatalError("Switch wasn't exhaustive for \(address) (\(String(address, radix: 16)) 😬")
            }
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            switch address {
            case 0x0000...0x1FFF:
                // Internal RAM and its mirrors
                internalRAM.write(value, to: address & 0x07FF)
            case 0x2000...0x3FFF:
                // TODO: - Retreive from PPU registers (only 8 bytes, subsequent bytes are mirrored)
                break
            case 0x4000...0x4017:
                // TODO: - Retreive from APU and IO registers
                break
            case 0x4018...0x401F:
                // APU and IO functionality that is normally disabled
                break
            case 0x4020...0xFFFF:
                // Writes to this range are often used for mapper control (bank switching)
                // Pass it off to the cartridge for proper mapping
                cartridge?.write(value, to: address)
            default:
                fatalError("Switch wasn't exhaustive for \(address) (\(String(address, radix: 16)) 😬")
            }
        }
    }
}
