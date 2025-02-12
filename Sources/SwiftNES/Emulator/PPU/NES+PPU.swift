extension NES {
    public class PPU {
        public struct Frame: Sendable {
            public let width: Int = 256
            public let height: Int = 240
            public let data: [UInt32]
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
        var frameCallback: ((Frame) -> Void)?
            
        public func setFrameCallback(_ callback: @escaping (Frame) -> Void) {
            frameCallback = callback
        }
            
        public func frameSequence() -> AsyncThrowingStream<Frame, Error> {
            AsyncThrowingStream { continuation in
                setFrameCallback { frame in
                    continuation.yield(frame)
                }
            }
        }
        
        private func outputFrame() {
            guard let frameCallback else { return }
            frameCallback(frameBuffer.makeFrame())
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
    }
}
