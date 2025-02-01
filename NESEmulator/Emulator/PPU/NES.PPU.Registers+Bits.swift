extension NES.PPU.Registers {
    /// PPU Control Register bits and configuration options
    struct PPUCtrl: OptionSet {
        var rawValue: UInt8
        
        /// Base nametable address selection (bits 0-1)
        /// Returns value 0-3 corresponding to nametables at $2000, $2400, $2800, or $2C00
        var baseNametableOption: UInt8 {
            get { rawValue & Self.baseNametableMask.rawValue }
            set {
                let otherBits = (rawValue & ~Self.baseNametableMask.rawValue)
                let newBits = (newValue & Self.baseNametableMask.rawValue)
                rawValue = otherBits | newBits
            }
        }
        
        /// Mask for base nametable selection (bits 0-1)
        private static let baseNametableMask = PPUCtrl(rawValue: 0b11)
        
        /// VRAM address increment per CPU read/write of PPUDATA
        /// false: increment by 1, true: increment by 32
        static let incrementVram = PPUCtrl(rawValue: 1 << 2)
        
        /// Sprite pattern table address for 8x8 sprites
        /// false: $0000, true: $1000
        static let spritePatternTableAddress = PPUCtrl(rawValue: 1 << 3)
        
        /// Background pattern table address
        /// false: $0000, true: $1000
        static let backgroundPatternTableAddress = PPUCtrl(rawValue: 1 << 4)
        
        /// Sprite size
        /// false: 8x8, true: 8x16
        static let spriteSize = PPUCtrl(rawValue: 1 << 5)
        
        /// PPU master/slave select (rarely used; most emulators ignore this)
        /// false: read backdrop from EXT pins, true: output color on EXT pins
        static let ppuMasterSlave = PPUCtrl(rawValue: 1 << 6)
        
        /// Generate NMI at the start of vblank
        /// false: off, true: on
        static let generateNMI = PPUCtrl(rawValue: 1 << 7)
        
        /// Converts base nametable selection to actual memory address
        var nametableBaseAddress: UInt16 {
            UInt16(baseNametableOption) * 0x400 + 0x2000
        }
        
        /// Amount to increment VRAM address by after PPUDATA access
        var vramAddressIncrement: UInt16 {
            contains(.incrementVram) ? 32 : 1
        }
        
        /// Current sprite height based on sprite size setting
        var spriteHeight: UInt8 {
            contains(.spriteSize) ? 16 : 8
        }
        
        /// Base address of sprite pattern table
        var spritePatternTableBaseAddress: UInt16 {
            contains(.spritePatternTableAddress) ? 0x1000 : 0x0000
        }

        /// Base address of background pattern table
        var backgroundPatternTableBaseAddress: UInt16 {
            contains(.backgroundPatternTableAddress) ? 0x1000 : 0x0000
        }
    }
    
    /// PPU Mask Register bits controlling rendering options
    struct PPUMask: OptionSet {
        var rawValue: UInt8
        
        /// Display in greyscale (0: normal color, 1: greyscale)
        static let greyscale = PPUMask(rawValue: 1 << 0)
        
        /// Show background in leftmost 8 pixels of screen
        static let showBackgroundLeft8Pixels = PPUMask(rawValue: 1 << 1)
        
        /// Show sprites in leftmost 8 pixels of screen
        static let showSpritesLeft8Pixels = PPUMask(rawValue: 1 << 2)
        
        /// Enable background rendering
        static let showBackground = PPUMask(rawValue: 1 << 3)
        
        /// Enable sprite rendering
        static let showSprites = PPUMask(rawValue: 1 << 4)
        
        /// Emphasize red (green on PAL/Dendy)
        static let emphasizeRed = PPUMask(rawValue: 1 << 5)
        
        /// Emphasize green (red on PAL/Dendy)
        static let emphasizeGreen = PPUMask(rawValue: 1 << 6)
        
        /// Emphasize blue
        static let emphasizeBlue = PPUMask(rawValue: 1 << 7)
    }
    
    /// PPU Status Register bits indicating PPU state
    struct PPUStatus: OptionSet {
        var rawValue: UInt8
        
        /// More than 8 sprites on current scanline
        /// - Note: Hardware implementation is buggy/unreliable
        static let spriteOverflow = PPUStatus(rawValue: 1 << 5)
        
        /// Sprite 0 hit occurred
        static let sprite0Hit = PPUStatus(rawValue: 1 << 6)
        
        /// Currently in vertical blank
        static let vblank = PPUStatus(rawValue: 1 << 7)
        
        /// Reads the status register and clears the vblank flag
        mutating func readAndClear() -> UInt8 {
            defer { remove(.vblank) }
            return rawValue
        }
    }
}
