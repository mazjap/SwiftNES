extension NES.PPU.Registers {
    /// PPU Control Register bits and configuration options
    public struct PPUCtrl: OptionSet, Sendable {
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// Base nametable address selection (bits 0-1)
        /// Returns value 0-3 corresponding to nametables at $2000, $2400, $2800, or $2C00
        public var baseNametableOption: UInt8 {
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
        public static let incrementVram = PPUCtrl(rawValue: 1 << 2)
        
        /// Sprite pattern table address for 8x8 sprites
        /// false: $0000, true: $1000
        public static let spritePatternTableAddress = PPUCtrl(rawValue: 1 << 3)
        
        /// Background pattern table address
        /// false: $0000, true: $1000
        public static let backgroundPatternTableAddress = PPUCtrl(rawValue: 1 << 4)
        
        /// Sprite size
        /// false: 8x8, true: 8x16
        public static let spriteSize = PPUCtrl(rawValue: 1 << 5)
        
        /// PPU master/slave select (rarely used; most emulators ignore this)
        /// false: read backdrop from EXT pins, true: output color on EXT pins
        public static let ppuMasterSlave = PPUCtrl(rawValue: 1 << 6)
        
        /// Generate NMI at the start of vblank
        /// false: off, true: on
        public static let generateNMI = PPUCtrl(rawValue: 1 << 7)
        
        /// Converts base nametable selection to actual memory address
        public var nametableBaseAddress: UInt16 {
            UInt16(baseNametableOption) * 0x400 + 0x2000
        }
        
        /// Amount to increment VRAM address by after PPUDATA access
        public var vramAddressIncrement: UInt16 {
            contains(.incrementVram) ? 32 : 1
        }
        
        /// Current sprite height based on sprite size setting
        public var spriteHeight: UInt8 {
            contains(.spriteSize) ? 16 : 8
        }
        
        /// Base address of sprite pattern table
        public var spritePatternTableBaseAddress: UInt16 {
            contains(.spritePatternTableAddress) ? 0x1000 : 0x0000
        }

        /// Base address of background pattern table
        public var backgroundPatternTableBaseAddress: UInt16 {
            contains(.backgroundPatternTableAddress) ? 0x1000 : 0x0000
        }
    }
    
    /// PPU Mask Register bits controlling rendering options
    public struct PPUMask: OptionSet, Sendable {
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// Display in greyscale (0: normal color, 1: greyscale)
        public static let greyscale = PPUMask(rawValue: 1 << 0)
        
        /// Show background in leftmost 8 pixels of screen
        public static let showBackgroundLeft8Pixels = PPUMask(rawValue: 1 << 1)
        
        /// Show sprites in leftmost 8 pixels of screen
        public static let showSpritesLeft8Pixels = PPUMask(rawValue: 1 << 2)
        
        /// Enable background rendering
        public static let showBackground = PPUMask(rawValue: 1 << 3)
        
        /// Enable sprite rendering
        public static let showSprites = PPUMask(rawValue: 1 << 4)
        
        /// Emphasize red (green on PAL/Dendy)
        public static let emphasizeRed = PPUMask(rawValue: 1 << 5)
        
        /// Emphasize green (red on PAL/Dendy)
        public static let emphasizeGreen = PPUMask(rawValue: 1 << 6)
        
        /// Emphasize blue
        public static let emphasizeBlue = PPUMask(rawValue: 1 << 7)
    }
    
    /// PPU Status Register bits indicating PPU state
    public struct PPUStatus: OptionSet, Sendable {
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// More than 8 sprites on current scanline
        /// - Note: Hardware implementation is buggy/unreliable
        public static let spriteOverflow = PPUStatus(rawValue: 1 << 5)
        
        /// Sprite 0 hit occurred
        public static let sprite0Hit = PPUStatus(rawValue: 1 << 6)
        
        /// Currently in vertical blank
        public static let vblank = PPUStatus(rawValue: 1 << 7)
        
        /// Reads the status register and clears the vblank flag
        public mutating func readAndClear() -> UInt8 {
            defer { remove(.vblank) }
            return rawValue
        }
    }
}
