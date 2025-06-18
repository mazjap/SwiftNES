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
    public enum FetchOperation {
        case nametable
        case attribute
        case patternLow
        case patternHigh
    }
    
    public struct FrameBuffer {
        public var pixels: [UInt32]
        
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
    public struct BackgroundFetchState {
        // Current fetch operation
        public var operation: FetchOperation = .nametable
        
        // Temporary data for current tile fetch
        public var nametableByte: UInt8 = 0
        public var attributeByte: UInt8 = 0
        public var patternLowByte: UInt8 = 0
        public var patternHighByte: UInt8 = 0
        
        // Current tile's palette attribute (2 bits)
        public var tileAttribute: UInt8 = 0
        
        // Pattern table shift registers (16 bits each)
        public var patternShiftLow: UInt16 = 0
        public var patternShiftHigh: UInt16 = 0
        
        // Attribute shift registers (8 bits, but only 2 bits used)
        public var attributeShiftLow: UInt8 = 0
        public var attributeShiftHigh: UInt8 = 0
        
        // Attribute latches for next tile
        public var attributeLatchLow: Bool = false
        public var attributeLatchHigh: Bool = false
        
        // Reset back to initial state
        public mutating func reset() {
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
    
    public struct SecondaryOAM {
        /// The maximum number of sprites per scanline (hardware limit)
        public static let capacity = 8
        
        /// Array of sprites visible on the current scanline, limited to 8
        public var sprites: [(y: UInt8, tile: UInt8, attributes: UInt8, x: UInt8)] = []
        
        /// Indicates if sprite 0 is among the visible sprites (for sprite 0 hit detection)
        public var sprite0Present = false
        
        /// Adds a sprite to secondary OAM if there's room (enforces 8 sprite limit)
        /// - Parameters:
        ///   - y: Y position (top of sprite)
        ///   - tile: Tile index
        ///   - attributes: Attribute byte
        ///   - x: X position (left of sprite)
        ///   - isSprite0: Whether this is sprite 0
        /// - Returns: True if the sprite was added, false if the secondary OAM is full
        public  mutating func addSprite(y: UInt8, tile: UInt8, attributes: UInt8, x: UInt8, isSprite0: Bool) -> Bool {
            // Enforce the 8 sprite per scanline limit
            guard sprites.count < Self.capacity else { return false }
            
            // Add the sprite
            sprites.append((y: y, tile: tile, attributes: attributes, x: x))
            
            // Track if sprite 0 is present
            if isSprite0 {
                sprite0Present = true
            }
            
            return true
        }
        
        /// Clears all sprites from secondary OAM
        public mutating func clear() {
            sprites.removeAll()
            sprite0Present = false
        }
    }
    
    /// Struct to track sprite pattern data for the current scanline
    public struct SpriteData {
        public var patternLow: UInt8 = 0
        public var patternHigh: UInt8 = 0
        public var attributes: UInt8 = 0
        public var xCounter: UInt8 = 0
        public var isSprite0: Bool = false
        public var active: Bool = false
        
        public mutating func reset() {
            patternLow = 0
            patternHigh = 0
            attributes = 0
            xCounter = 0
            isSprite0 = false
            active = false
        }
        
        public init(
            patternLow: UInt8 = 0,
            patternHigh: UInt8 = 0,
            attributes: UInt8 = 0,
            x: UInt8 = 0,
            isSprite0: Bool = false,
            active: Bool = false
        ) {
            self.patternLow = patternLow
            self.patternHigh = patternHigh
            self.attributes = attributes
            self.xCounter = x
            self.isSprite0 = isSprite0
            self.active = active
        }
        
        /// Get the color index for this sprite at the current position
        /// - Returns: Color index (0-3) or nil if transparent
        public func getColorIndex() -> UInt8? {
            // If not active, no pixel
            if !active { return nil }
            
            // If x counter hasn't reached 0, no pixel yet
            if xCounter > 0 { return nil }
            
            // Get the bit position (depends on horizontal flip)
            let isFlipped = (attributes & 0x40) != 0
            let bit = isFlipped ? 0 : 7
            
            // Get the pixel bits from pattern data
            let lowBit = (patternLow >> bit) & 0x01
            let highBit = (patternHigh >> bit) & 0x01
            
            // Combine bits to get color index (0-3)
            let colorIndex = (highBit << 1) | lowBit
            
            // Return nil for transparent pixels (index 0)
            return colorIndex != 0 ? colorIndex : nil
        }
        
        /// Shift the sprite pattern data for the next pixel
        public mutating func shift() {
            // If the sprite is horizontally flipped, shift right instead of left
            if (attributes & 0x40) != 0 {
                // Horizontally flipped - shift right
                patternLow >>= 1
                patternHigh >>= 1
            } else {
                // Normal - shift left
                patternLow <<= 1
                patternHigh <<= 1
            }
        }
    }
    
    public enum SpriteFetchOperation {
        case garbageNT // Garbage nametable fetch
        case garbageAT // Garbage attribute fetch (not used but included for completeness)
        case patternLow // Sprite pattern table low byte
        case patternHigh // Sprite pattern table high byte
    }
    
    /// State tracking for sprite fetching during cycles 257-320
    public struct SpriteFetchState {
        public var currentSprite: Int = 0 // Current sprite being fetched (0-7)
        public var operation: SpriteFetchOperation = .garbageNT  // Current fetch operation
        public var fetchCycle: Int = 0 // Cycle within the current sprite fetch (0-7)
        
        // Temporary data for the current sprite being fetched
        public var tileIndex: UInt8 = 0
        public var attributes: UInt8 = 0
        public var xPosition: UInt8 = 0
        public var yPosition: UInt8 = 0
        public var spriteRowY: Int = 0 // Which row of the tile we need
        public var isSprite0: Bool = false // Whether this is sprite 0
        public var patternTableAddress: UInt16 = 0 // Base address in pattern table
        public var patternLowByte: UInt8 = 0 // Low byte of pattern data
        public var patternHighByte: UInt8 = 0 // High byte of pattern data
        
        /// Reset the sprite fetch state for a new sprite evaluation phase
        public mutating func reset() {
            currentSprite = 0
            operation = .garbageNT
            fetchCycle = 0
            tileIndex = 0
            attributes = 0
            xPosition = 0
            yPosition = 0
            spriteRowY = 0
            isSprite0 = false
            patternTableAddress = 0
            patternLowByte = 0
            patternHighByte = 0
        }
    }
}
