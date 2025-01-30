extension NES.PPU.Registers {
    struct PPUCtrl: OptionSet {
        var rawValue: UInt8
        
        var baseNametableOption: UInt8 {
            get { rawValue & Self.baseNametableMask.rawValue }
            set {
                let otherBits = (rawValue & ~Self.baseNametableMask.rawValue)
                let newBits = (newValue & Self.baseNametableMask.rawValue)
                
                rawValue = otherBits | newBits
            }
        }
        
        // An enum of where nametable is located in memory
        private static let baseNametableMask = PPUCtrl(rawValue: 0b11)
        // 0: +1, 1: +32
        static let incrementVram = PPUCtrl(rawValue: 1 << 2)
        // 0: 0x0000, 1: 0x1000
        static let spritePatternTableAddress = PPUCtrl(rawValue: 1 << 3)
        // 0: 0x0000, 1: 0x1000
        static let backgroundPatternTableAddress = PPUCtrl(rawValue: 1 << 4)
        // 0: 8x8, 1: 8x16
        static let spriteSize = PPUCtrl(rawValue: 1 << 5)
        // 0: read backdrop, 1: output color
        static let ppuMasterSlave = PPUCtrl(rawValue: 1 << 6)
        // 0: off, 1: on
        static let generateNMI = PPUCtrl(rawValue: 1 << 7)
        
        // Convert 0-3 to actual memory addresses
        var nametableBaseAddress: UInt16 {
            UInt16(baseNametableOption) * 0x400
        }
        
        var vramAddressIncrement: UInt16 {
            contains(.incrementVram) ? 32 : 1
        }
        
        var spriteHeight: UInt8 {
            contains(.spriteSize) ? 16 : 8
        }
        
        var spritePatternTableBaseAddress: UInt16 {
            contains(.spritePatternTableAddress) ? 0x1000 : 0x0000
        }

        var backgroundPatternTableBaseAddress: UInt16 {
            contains(.backgroundPatternTableAddress) ? 0x1000 : 0x0000
        }
    }
    
    struct PPUMask: OptionSet {
        var rawValue: UInt8
        
        static let greyscale = PPUMask(rawValue: 1 << 0)
        static let showBackgroundLeft8Pixels = PPUMask(rawValue: 1 << 1)
        static let showSpritesLeft8Pixels = PPUMask(rawValue: 1 << 2)
        static let showBackground = PPUMask(rawValue: 1 << 3)
        static let showSprites = PPUMask(rawValue: 1 << 4)
        static let emphasizeRed = PPUMask(rawValue: 1 << 5)
        static let emphasizeGreen = PPUMask(rawValue: 1 << 6)
        static let emphasizeBlue = PPUMask(rawValue: 1 << 7)
    }
    
    struct PPUStatus: OptionSet {
        var rawValue: UInt8
        
        // Lower 5 bits unused in Status register
        static let spriteOverflow = PPUStatus(rawValue: 1 << 5)
        static let sprite0Hit = PPUStatus(rawValue: 1 << 6)
        static let vblank = PPUStatus(rawValue: 1 << 7)
        
        // Reading Status clears bit 7 and resets write toggle
        mutating func readAndClear() -> UInt8 {
            defer { remove(.vblank) }
            
            return rawValue
        }
    }
}
