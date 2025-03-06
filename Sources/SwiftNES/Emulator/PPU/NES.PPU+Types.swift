// MARK: - Public Types

extension NES.PPU {
    // For debugging purposes
    public enum RenderState {
        case visible     // Cycles 1-256: Render pixels, fetch tiles/sprites
        case spriteEval  // Cycles 257-320: Sprite evaluation for next line
        case prefetch    // Cycles 321-336: Prefetch first two tiles of next line
        case fetchNT     // Fetching nametable byte
        case fetchAT     // Fetching attribute table byte
        case fetchPTLow  // Fetching pattern table low byte
        case fetchPTHigh // Fetching pattern table high byte
        case idle        // During VBlank or when rendering is disabled
    }
    
    public struct Frame: Sendable {
        public static let width: Int = 256
        public static let height: Int = 240
        public static let pixelCount: Int = width * height
        
        /// In RGB format. Use the convenience functions, `toRGBA()` or `toBGRA()`
        /// to get compatible color formats for your rendering method
        public let data: [UInt32]
        
        /// Converts the frame's RGB data to ARGB format by adding an opaque alpha channel
        /// Useful for rendering with APIs that expect ARGB pixel format like Metal's MTLPixelFormat.rgba8Unorm
        /// - Returns: Array of pixels in ARGB format with full opacity (0xFF alpha | 0xAARRGGBB)
        public func toARGB() -> [UInt32] {
            data.map { $0 | 0xFF000000 }
        }
        
        /// Converts the frame's RGB data to ABGR format by swapping R and B channels and adding an opaque alpha channel
        /// Useful for rendering with APIs that expect ABGR pixel format like Metal's MTLPixelFormat.bgra8Unorm
        /// - Returns: Array of pixels in ABGR format with full opacity (0xFF alpha | 0xAABBGGRR)
        public func toABGR() -> [UInt32] {
            data.map { rgb in
                let r = (rgb >> 16) & 0xFF
                let g = (rgb >> 8) & 0xFF
                let b = rgb & 0xFF
                return 0xFF000000 | (b << 16) | (g << 8) | r
            }
        }
        
        public func isValidPosition(x: Int, y: Int) -> Bool {
            x >= 0 && x < Self.width && y >= 0 && y < Self.height
        }
        
        public func positionFor(x: Int, y: Int) -> Int {
            y * Self.width + x
        }
    }
}

// MARK: - Internal Types

extension NES.PPU {
    /// Tracks current fetch operation during the 8-cycle pattern
    enum FetchOperation {
        case nametable
        case attribute
        case patternLow
        case patternHigh
    }
    
    struct FrameBuffer {
        private var pixels: [UInt32]
        
        init() {
            self.pixels = [UInt32](repeating: 0, count: 256 * 240)
        }
        
        mutating func setPixel(x: Int, y: Int, color: UInt32) {
            guard x >= 0 && x < 256 && y >= 0 && y < 240 else { return }
            pixels[y * 256 + x] = color
        }
        
        func makeFrame() -> Frame {
            Frame(data: pixels)
        }
    }
    
    /// State needed for background tile fetching
    struct BackgroundFetchState {
        // Current fetch operation
        var operation: FetchOperation = .nametable
        
        // Temporary data for current tile fetch
        var nametableByte: UInt8 = 0
        var attributeByte: UInt8 = 0
        var patternLowByte: UInt8 = 0
        var patternHighByte: UInt8 = 0
        
        // Current tile's palette attribute (2 bits)
        var tileAttribute: UInt8 = 0
        
        // Pattern table shift registers (16 bits each)
        var patternShiftLow: UInt16 = 0
        var patternShiftHigh: UInt16 = 0
        
        // Attribute shift registers (8 bits, but only 2 bits used)
        var attributeShiftLow: UInt8 = 0
        var attributeShiftHigh: UInt8 = 0
        
        // Attribute latches for next tile
        var attributeLatchLow: Bool = false
        var attributeLatchHigh: Bool = false
        
        // Reset back to initial state
        mutating func reset() {
            operation = .nametable
            nametableByte = 0
            attributeByte = 0
            patternLowByte = 0
            patternHighByte = 0
            tileAttribute = 0
            
            // Don't reset shift registers on scanline reset
            // as they need to continue shifting across tile boundaries
        }
    }
    
    struct SecondaryOAM {
        static let capacity = 8
        var sprites: [(y: UInt8, tile: UInt8, attributes: UInt8, x: UInt8)] = []
        var sprite0Present = false
    }
    
    /// Struct to track sprite pattern data for the current scanline
    struct SpriteData {
        // Pattern data (low and high bytes)
        var patternLow: UInt8 = 0
        var patternHigh: UInt8 = 0
        
        // Sprite attributes
        var attributes: UInt8 = 0
        
        // X position counter
        var xCounter: UInt8 = 0
        
        // Is this sprite 0?
        var isSprite0: Bool = false
        
        // Is this sprite active?
        var active: Bool = false
        
        /// Reset sprite data
        mutating func reset() {
            patternLow = 0
            patternHigh = 0
            attributes = 0
            xCounter = 0
            isSprite0 = false
            active = false
        }
        
        /// Initialize with sprite data
        init(patternLow: UInt8, patternHigh: UInt8, attributes: UInt8, x: UInt8, isSprite0: Bool) {
            self.patternLow = patternLow
            self.patternHigh = patternHigh
            self.attributes = attributes
            self.xCounter = x
            self.isSprite0 = isSprite0
            self.active = true
        }
        
        /// Default initializer
        init() {}
        
        /// Get the color index for this sprite at the current position
        /// - Returns: Color index (0-3) or nil if transparent
        func getColorIndex() -> UInt8? {
            // If not active or x counter hasn't reached 0, no pixel
            if !active || xCounter > 0 {
                return nil
            }
            
            // Get the bit position (depends on horizontal flip)
            let bit = (attributes & 0x40) != 0 ? 0 : 7
            
            // Get the pixel bits from pattern data
            let lowBit = (patternLow >> bit) & 0x01
            let highBit = (patternHigh >> bit) & 0x01
            
            // Combine bits to get color index (0-3)
            let colorIndex = (highBit << 1) | lowBit
            
            // Return nil for transparent pixels (index 0)
            return colorIndex != 0 ? colorIndex : nil
        }
        
        /// Shift the sprite pattern data left by one bit
        mutating func shift() {
            // If x counter is still counting down, decrement it
            if xCounter > 0 {
                xCounter -= 1
                return
            }
            
            // Otherwise, shift the pattern data
            if (attributes & 0x40) != 0 {
                // Horizontal flip - shift right
                patternLow >>= 1
                patternHigh >>= 1
            } else {
                // Normal - shift left
                patternLow <<= 1
                patternHigh <<= 1
            }
        }
    }
}
