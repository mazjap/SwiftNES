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
                let vramAddr = resolveNametableAddress(address)
                return vram[Int(vramAddr)]
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
                let vramAddr = resolveNametableAddress(address)
                vram[Int(vramAddr)] = value
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
        
        /// Fetches an 8x8 tile from the pattern table
        /// - Parameters:
        ///   - tileIndex: Index of the tile in pattern table (0-255)
        ///   - table: Which pattern table to use (0 or 1)
        /// - Returns: Array of 8 bytes for the low bit plane and 8 bytes for the high bit plane
        func fetchTileData(tileIndex: UInt8, table: UInt8) -> (lowPlane: [UInt8], highPlane: [UInt8]) {
            let baseAddr = UInt16(table) * 0x1000 // Each table is 4KB (0x1000 bytes)
            let tileAddr = baseAddr + UInt16(tileIndex) * 16 // Each tile is 16 bytes
            
            var lowPlane = [UInt8]()
            var highPlane = [UInt8]()
            
            // First 8 bytes are low bit plane
            for i in 0..<8 {
                lowPlane.append(read(from: tileAddr + UInt16(i)))
            }
            
            // Next 8 bytes are high bit plane
            for i in 0..<8 {
                highPlane.append(read(from: tileAddr + UInt16(i + 8)))
            }
            
            return (lowPlane, highPlane)
        }
        
        /// Decodes a single row of an 8x8 tile
        /// - Parameters:
        ///   - lowByte: Byte from the low bit plane
        ///   - highByte: Byte from the high bit plane
        /// - Returns: Array of 8 2-bit values representing pixel pattern indices
        func decodeTileRow(lowByte: UInt8, highByte: UInt8) -> [UInt8] {
            var row = [UInt8](repeating: 0, count: 8)
            
            for bit in 0..<8 {
                let lowBit = (lowByte >> (7 - bit)) & 0x1
                let highBit = (highByte >> (7 - bit)) & 0x1
                row[bit] = (highBit << 1) | lowBit
            }
            
            return row
        }
        
        /// Fetches and decodes a complete 8x8 tile
        /// - Parameters:
        ///   - tileIndex: Index of the tile in pattern table (0-255)
        ///   - table: Which pattern table to use (0 or 1)
        /// - Returns: 8x8 array of pattern indices (0-3)
        func fetchDecodedTile(tileIndex: UInt8, table: UInt8) -> [[UInt8]] {
            let (lowPlane, highPlane) = fetchTileData(tileIndex: tileIndex, table: table)
            var tile = [[UInt8]](repeating: [UInt8](repeating: 0, count: 8), count: 8)
            
            for row in 0..<8 {
                tile[row] = decodeTileRow(lowByte: lowPlane[row], highByte: highPlane[row])
            }
            
            return tile
        }
        
        /// Resolve a nametable address based on Cartridge's mirroring mode
        func resolveNametableAddress(_ address: UInt16) -> UInt16 {
            // Extract the nametable number (0-3) from bits 10-11
            let nametableNum = (address >> 10) & 0x3
            
            // Get the base nametable address (0x2000-0x2C00, in steps of 0x400)
            let baseAddr = 0x2000 + (nametableNum * 0x400)
            
            // Get the offset within the nametable (0-0x3FF)
            let offset = address & 0x3FF
            
            // For the physical VRAM address, we need to map the logical nametable
            // to one of the two physical nametables based on mirroring
            var vramAddr: UInt16
            
            switch cartridge?.mapper.mirroringMode {
            case .vertical:
                // Nametables 0,2 -> first 1KB, 1,3 -> second 1KB
                vramAddr = ((baseAddr & 0x800) == 0) ? offset : (0x400 + offset)
                
            case .singleScreenLower:
                // All nametables -> first 1KB
                vramAddr = offset
                
            case .singleScreenUpper:
                // All nametables -> second 1KB
                vramAddr = 0x400 + offset
                
            case .fourScreen:
                fallthrough // TODO: - Implement four-screen mirroring. All your VRAM are belong to us.
            case .horizontal, .none: // Default to horizontal mirroring if no cartridge
                // Nametables 0,1 -> first 1KB, 2,3 -> second 1KB
                vramAddr = (baseAddr < 0x2800) ? offset : (0x400 + offset)
            }
            
            return vramAddr
        }
    }
}
