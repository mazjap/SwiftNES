extension NES.PPU {
    class Memory {
        // 2KB of VRAM for nametables
        private var vram: [UInt8]
        // 256 bytes for sprite data
        private var oamRam: [UInt8]
        // 32 bytes for palettes
        private var paletteRam: [UInt8]
        // For accessing cartridge CHR ROM/RAM
        private weak var cartridge: NES.Cartridge?
        
        init(cartridge: NES.Cartridge?) {
            self.vram = [UInt8](repeating: 0, count: 0x800) // 2KB
            self.oamRam = [UInt8](repeating: 0, count: 0x100) // 256B
            self.paletteRam = [UInt8](repeating: 0, count: 32) // 32B
            self.cartridge = cartridge
        }
        
        func read(from address: UInt16) -> UInt8 {
            switch address & 0x3FFF {  // Mirror everything above $3FFF
            case 0x0000...0x1FFF:  // Pattern Tables
                guard let cartridge else {
                    emuLogger.error("Attempted to read pattern table with no cartridge present")
                    return 0
                }
                
                return cartridge.read(from: address)
            case 0x2000...0x2FFF:  // Nametables
                return vram[Int(address & 0x7FF)]  // Mirror every 2KB
            case 0x3000...0x3EFF:  // Nametable mirrors
                return read(from: address & 0x2FFF)
            case 0x3F00...0x3FFF:  // Palette RAM
                return readPalette(from: address)
            default:
                emuLogger.error("PPU attempted to read from invalid address: \(String(format: "0x%04X", address))")
                return 0
            }
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            switch address & 0x3FFF {
            case 0x0000...0x1FFF: // Pattern Tables
                guard let cartridge else {
                    emuLogger.error("Attempted to write to pattern table with no cartridge present")
                    return
                }
                
                cartridge.write(value, to: address)
            case 0x2000...0x2FFF: // Nametables
                vram[Int(address & 0x7FF)] = value
            case 0x3000...0x3EFF: // Nametable mirrors
                write(value, to: address & 0x2FFF)
            case 0x3F00...0x3FFF: // Palette RAM
                write(value, to: address)
            default:
                emuLogger.error("PPU attempted to write \(String(format: "0x%02X", value)) to invalid address: \(String(format: "0x%04X", address))")
            }
        }
        
        // For OAM DMA and sprite operations
        func readOAM(from address: UInt8) -> UInt8 {
            oamRam[Int(address)]
        }
        
        func writeOAM(_ value: UInt8, to address: UInt8) {
            oamRam[Int(address)] = value
        }
        
        func readPalette(from address: UInt16) -> UInt8 {
            let paletteAddr = Int(address & 0x1F)
            
            // $3F10/$3F14/$3F18/$3F1C mirror $3F00/$3F04/$3F08/$3F0C
            if paletteAddr & 0x13 == 0x10 {
                return paletteRam[paletteAddr & 0xF]
            }
            
            return paletteRam[paletteAddr]
        }

        func writePalette(_ value: UInt8, to address: UInt16) {
            let paletteAddr = Int(address & 0x1F)
            
            // $3F10/$3F14/$3F18/$3F1C mirror $3F00/$3F04/$3F08/$3F0C
            if paletteAddr & 0x13 == 0x10 {
                paletteRam[paletteAddr & 0xF] = value
            } else {
                paletteRam[paletteAddr] = value
            }
        }
    }
}
