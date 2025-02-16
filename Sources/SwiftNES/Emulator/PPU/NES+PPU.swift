extension NES {
    public class PPU {
        public struct Frame: Sendable {
            public static let width: Int = 256
            public static let height: Int = 240
            public static let pixelCount: Int = width * height
            
            /// In RGB format. Use the convenience functions, `toRGBA()` or `toBGRA()`
            /// to get compatible color formats for your rendering method
            public let data: [UInt32]
            
            /// Converts the frame's RGB data to ARGB format by adding an opaque alpha channel
            /// Useful for rendering with APIs that expect RGBA pixel format like Metal's MTLPixelFormat.rgba8Unorm
            /// - Returns: Array of pixels in RGBA format with full opacity (0xFF alpha | 0xAARRGGBB)
            public func toARGB() -> [UInt32] {
                data.map { $0 | 0xFF000000 }
            }
            
            /// Converts the frame's RGB data to ABGR format by swapping R and B channels and adding an opaque alpha channel
            /// Useful for rendering with APIs that expect BGRA pixel format like Metal's MTLPixelFormat.bgra8Unorm
            /// - Returns: Array of pixels in BGRA format with full opacity (0xFF alpha | 0xAABBGGRR)
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
        
        var registers: Registers
        var cycle: Int = 0 // 0-340 pixels per scanline
        var scanline: Int = 0 // 0-261 scanlines per frame
        var frame: Int = 0
        var isOddFrame: Bool = false // Used for skipped cycle on odd frames
        var memory: Memory
        var setNMI: () -> Void
        var frameBuffer: FrameBuffer
        // TODO: - Solidify Result Error type to specific cases
        var frameCallback: ((Result<Frame, Error>) -> Void)?
            
        public func setFrameCallback(_ callback: @escaping (Result<Frame, Error>) -> Void) {
            frameCallback = callback
        }
            
        public func frameSequence() -> AsyncThrowingStream<Frame, Error> {
            AsyncThrowingStream { continuation in
                setFrameCallback { result in
                    continuation.yield(with: result)
                }
            }
        }
        
        private func colorFromPaletteIndex(_ index: UInt8) -> UInt32 {
            Self.masterPalette[Int(index & 0x3F)]
        }
        
        private func outputFrame() {
            guard let frameCallback else { return }
            frameCallback(.success(frameBuffer.makeFrame()))
        }
        
        init(memoryManager: MMU, setNMI: @escaping () -> Void) {
            let memory = Memory(cartridge: memoryManager.cartridge)
            
            self.memory = memory
            self.setNMI = setNMI
            
            self.registers = Registers(
                memory: memory,
                ctrl: .init(rawValue: 0),
                mask: .init(rawValue: 0),
                status: .init(rawValue: 0),
                oamAddr: 0,
                scroll: 0,
                addr: 0,
                oamDma: 0
            )
            
            self.frameBuffer = FrameBuffer()
        }
        
        func step(_ cycleCount: UInt8) {
            if scanline == -1 && cycle == 1 {
                // Clear VBlank, sprite 0, overflow flags
                registers.status.rawValue = 0
            }
            
            if scanline >= 0 && scanline < 240 {
                // Handle visible scanlines
            } else if scanline == 241 && cycle == 1 {
                // Output the frame, set VBlank flag, and trigger NMI if enabled
                outputFrame()
                
                registers.status.insert(.vblank)
                if registers.ctrl.contains(.generateNMI) {
                    // Signal NMI to CPU
                    setNMI()
                }
            }
            
            // Advance PPU state
            cycle += 1
            if cycle > 340 {
                cycle = 0
                scanline += 1
                if scanline > 261 {
                    scanline = -1
                    frame += 1
                    isOddFrame = !isOddFrame
                }
            }
        }
        
        func reset() {
            // TODO: - Implement me
        }
        
        func read(from register: UInt8) -> UInt8 {
            registers.read(from: register)
        }
        
        func write(_ value: UInt8, to register: UInt8) {
            registers.write(value, to: register)
        }
        
        private static let masterPalette: [UInt32] = [
            0x626262, 0x001FB2, 0x2404C8, 0x5200B2, // 0x00-0x03
            0x730076, 0x800024, 0x730B00, 0x522800, // 0x04-0x07
            0x244400, 0x005700, 0x005C00, 0x005324, // 0x08-0x0B
            0x003C76, 0x000000, 0x000000, 0x000000, // 0x0C-0x0F
            0xABABAB, 0x0D57FF, 0x4B30FF, 0x8A13FF, // 0x10-0x13
            0xBC08D6, 0xD21269, 0xC72E00, 0x9D5400, // 0x14-0x17
            0x607B00, 0x209800, 0x00A300, 0x009942, // 0x18-0x1B
            0x007DB4, 0x000000, 0x000000, 0x000000, // 0x1C-0x1F
            0xFFFFFF, 0x53AEFF, 0x9085FF, 0xD365FF, // 0x20-0x03
            0xFF57FF, 0xFF5DCF, 0xFF7757, 0xFA9E00, // 0x24-0x27
            0xBDC700, 0x7AE700, 0x43F611, 0x26EF7E, // 0x28-0x2B
            0x2CD5F6, 0x4E4E4E, 0x000000, 0x000000, // 0x2C-0x2F
            0xFFFFFF, 0xB6E1FF, 0xCED1FF, 0xE9C3FF, // 0x30-0x33
            0xFFBCFF, 0xFFBDF4, 0xFFC6C3, 0xFFD59A, // 0x34-0x37
            0xE9E681, 0xCEF481, 0xB6FB9A, 0xA9FAC3, // 0x38-0x3B
            0xA9F0F4, 0xB8B8B8, 0x000000, 0x000000  // 0x3C-0x3F
        ]
    }
}
