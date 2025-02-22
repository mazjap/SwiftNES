extension NES {
    public class PPU {
        var registers: Registers
        var cycle: Int = 0 // 0-340 pixels per scanline
        var scanline: Int = 0 // 0-261 scanlines per frame
        var frame: Int = 0
        var isOddFrame: Bool = false // Used for skipped cycle on odd frames
        var memory: Memory
        var nmiPending = false
        var triggerNMI: () -> Void
        var bgFetchState = BackgroundFetchState()
        var frameBuffer: FrameBuffer
        // TODO: - Solidify Result Error type to specific cases
        var frameCallback: ((Result<Frame, Error>) -> Void)?
        public internal(set) var renderState: RenderState = .idle
        
        init(memoryManager: MMU, triggerNMI: @escaping () -> Void) {
            let memory = Memory(cartridge: memoryManager.cartridge)
            
            self.memory = memory
            self.triggerNMI = triggerNMI
            
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
        
        // MARK: - Internal Functions
        
        func step(_ cycleCount: UInt8) {
            // Pre-render scanline
            if scanline == 261 {
                if cycle == 1 {
                    // Clear status flags related to the last frame
                    registers.status.remove([.vblank, .sprite0Hit, .spriteOverflow])
                    
                    // Also clear pending NMI if it was set
                    nmiPending = false
                }
            }
            
            // Handle VRAM address updates and render states
            updateAddressDuringRendering()
            
            // Start of VBlank (scanline 241)
            if scanline == 241 && cycle == 1 {
                renderState = .idle
                registers.status.insert(.vblank)
                
                outputFrame()
                
                if registers.ctrl.contains(.generateNMI) {
                    triggerNMI()
                }
                
                // Set NMI pending for edge case handling with later PPUCTRL writes
                nmiPending = true
            }
            
            // Advance PPU state
            cycle += 1
            if cycle > 340 {
                cycle = 0
                scanline += 1
                if scanline > 261 {
                    scanline = 0
                    frame += 1
                    isOddFrame = !isOddFrame
                    
                    // Skip cycle 0 on odd frames when rendering is enabled
                    if isOddFrame && (registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites)) {
                        cycle = 1
                    }
                }
            }
        }
        
        func reset() {
            // TODO: - Implement me
        }
        
        func read(from register: UInt8) -> UInt8 {
            switch register {
            case 0x02: // PPUSTATUS
                return readStatus()
            default:
                return registers.read(from: register)
            }
        }
        
        func write(_ value: UInt8, to register: UInt8) {
            switch register {
            case 0x00: // PPUCTRL
                writeControl(value)
            default:
                registers.write(value, to: register)
            }
        }
        
        // MARK: - Private Functions
        
        private func colorFromPaletteIndex(_ index: UInt8) -> UInt32 {
            Self.masterPalette[Int(index & 0x3F)]
        }
        
        private func outputFrame() {
            guard let frameCallback else { return }
            frameCallback(.success(frameBuffer.makeFrame()))
        }
        
        private func incrementHorizontalPosition() {
            if !registers.mask.contains(.showBackground) && !registers.mask.contains(.showSprites) {
                return
            }
            
            // Increment coarse X
            if (registers.currentVramAddress & 0x001F) == 31 {
                // If coarse X == 31, wrap to next nametable
                registers.currentVramAddress &= ~0x001F // Clear coarse X
                registers.currentVramAddress ^= 0x0400 // Switch horizontal nametable
            } else {
                registers.currentVramAddress += 1 // Increment coarse X
            }
        }

        private func incrementVerticalPosition() {
            if !registers.mask.contains(.showBackground) && !registers.mask.contains(.showSprites) {
                return
            }
            
            // Increment fine Y
            if (registers.currentVramAddress & 0x7000) != 0x7000 {
                registers.currentVramAddress += 0x1000
            } else {
                // Fine Y = 0
                registers.currentVramAddress &= ~0x7000
                
                // Increment coarse Y
                var y = (registers.currentVramAddress & 0x03E0) >> 5
                if y == 29 {
                    // Wrap to next nametable
                    y = 0
                    registers.currentVramAddress ^= 0x0800
                } else if y == 31 {
                    // Wrap without switching nametable
                    y = 0
                } else {
                    y += 1
                }
                
                // Put coarse Y back into v
                registers.currentVramAddress = (registers.currentVramAddress & ~0x03E0) | (y << 5)
            }
        }
        
        /// Updates the VRAM address registers during active rendering
        private func updateAddressDuringRendering() {
            // Only update if rendering is enabled
            if !(registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites)) {
                return
            }
            
            // Active scanlines only (0-239)
            if scanline >= 0 && scanline < 240 {
                if cycle == 0 {
                    // Idle cycle
                    renderState = .idle
                } else if cycle <= 256 {
                    // Visible pixels + tile/sprite fetching
                    renderState = .visible
                    
                    renderPixel()
                    
                    // Every 8 cycles, increment coarse X
                    if cycle % 8 == 0 {
                        incrementHorizontalPosition()
                    }
                    
                    // Fetch background tiles during visible cycles
                    fetchBackgroundTile()
                    
                    if cycle == 256 {
                        // At the end of scanline, increment Y position
                        incrementVerticalPosition()
                    }
                } else if cycle <= 320 {
                    // Sprite evaluation for next line
                    renderState = .spriteEval
                    // TODO: Implement sprite evaluation
                } else if cycle <= 336 {
                    // Prefetch first two tiles of next line
                    renderState = .prefetch
                    
                    // Continue fetching during prefetch cycles
                    fetchBackgroundTile()
                }
            }
            
            // At cycle 257, copy horizontal bits from t to v
            if cycle == 257 {
                // Copy horizontal bits from t to v (coarse X, nametable select X)
                registers.currentVramAddress = (registers.currentVramAddress & ~0x041F) |
                                              (registers.tempVramAddress & 0x041F)
            }
            
            // During pre-render scanline (261), copy vertical bits from t to v
            if scanline == 261 {
                // Between cycles 280-304, copy vertical bits
                if cycle >= 280 && cycle <= 304 {
                    // Copy vertical bits from t to v (coarse Y, fine Y, nametable select Y)
                    registers.currentVramAddress = (registers.currentVramAddress & ~0x7BE0) |
                                                  (registers.tempVramAddress & 0x7BE0)
                }
            }
        }
        
        /// Performs background tile fetching based on current PPU cycle
        private func fetchBackgroundTile() {
            // Only fetch during active rendering
            guard registers.mask.contains(.showBackground) else {
                return
            }
            
            // Reset fetch state at the start of each scanline
            if cycle == 0 {
                bgFetchState.reset()
            }
            
            // Each fetch operation takes 2 cycles
            let fetchCycle = (cycle % 8) / 2
            
            switch fetchCycle {
            case 0: // Nametable byte fetch
                // Calculate nametable address from current VRAM address
                let nametableAddr = 0x2000 | (registers.currentVramAddress & 0x0FFF)
                bgFetchState.nametableByte = memory.read(from: nametableAddr)
                bgFetchState.operation = .attribute
                
            case 1: // Attribute table byte fetch
                // Calculate attribute address
                let v = registers.currentVramAddress
                let attributeAddr = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07)
                bgFetchState.attributeByte = memory.read(from: attributeAddr)
                
                // Extract the correct 2 bits based on tile position
                let shift = ((v >> 4) & 4) | (v & 2)
                bgFetchState.tileAttribute = (bgFetchState.attributeByte >> shift) & 0x3
                bgFetchState.operation = .patternLow
                
            case 2: // Pattern table low byte fetch
                let patternAddr = registers.ctrl.backgroundPatternTableBaseAddress |
                                (UInt16(bgFetchState.nametableByte) << 4) |
                                ((registers.currentVramAddress >> 12) & 7)
                bgFetchState.patternLowByte = memory.read(from: patternAddr)
                bgFetchState.operation = .patternHigh
                
            case 3: // Pattern table high byte fetch
                let patternAddr = registers.ctrl.backgroundPatternTableBaseAddress |
                                (UInt16(bgFetchState.nametableByte) << 4) |
                                ((registers.currentVramAddress >> 12) & 7) | 8
                bgFetchState.patternHighByte = memory.read(from: patternAddr)
                
                // At end of fetch, load shift registers (implemented in next step)
                loadBackgroundShiftRegisters()
                bgFetchState.operation = .nametable
                
            default:
                break
            }
        }
        
        /// Loads the shift registers with new tile data at the end of each fetch cycle
        private func loadBackgroundShiftRegisters() {
            // Shift previous contents left by 8 bits
            bgFetchState.patternShiftLow = (bgFetchState.patternShiftLow & 0xFF00) | UInt16(bgFetchState.patternLowByte)
            bgFetchState.patternShiftHigh = (bgFetchState.patternShiftHigh & 0xFF00) | UInt16(bgFetchState.patternHighByte)
            
            // Set attribute latches based on current attribute bits
            bgFetchState.attributeLatchLow = bgFetchState.tileAttribute & 0x01 > 0 ? 0xFF : 0x00
            bgFetchState.attributeLatchHigh = bgFetchState.tileAttribute & 0x02 > 0 ? 0xFF : 0x00
            
            // Load attribute shifts based on latches
            bgFetchState.attributeShiftLow = (bgFetchState.attributeShiftLow & 0xF0) | (bgFetchState.attributeLatchLow & 0x0F)
            bgFetchState.attributeShiftHigh = (bgFetchState.attributeShiftHigh & 0xF0) | (bgFetchState.attributeLatchHigh & 0x0F)
        }
        
        /// Handle PPUSTATUS register read with proper NMI timing
        private func readStatus() -> UInt8 {
            let currentStatus = registers.status.readAndClear()
            registers.writeToggle = false
            
            // If reading status exactly at VBlank set (race condition),
            // prevent NMI from occurring this frame by clearing the pending flag
            if scanline == 241 && cycle <= 3 {
                nmiPending = false
            }
            
            return currentStatus
        }
        
        /// Handle PPUCTRL register write with proper NMI timing
        private func writeControl(_ value: UInt8) {
            let oldNMIEnabled = registers.ctrl.contains(.generateNMI)
            registers.ctrl.rawValue = value
            
            // If NMI enabled during VBlank period and previously disabled,
            // and VBlank flag is set, trigger an NMI immediately
            if !oldNMIEnabled && registers.ctrl.contains(.generateNMI) &&
               registers.status.contains(.vblank) && nmiPending {
                triggerNMI()
            }
        }
        
        /// Shifts all background registers by one bit
        private func shiftBackgroundRegisters() {
            // Only shift during rendering
            guard registers.mask.contains(.showBackground) else {
                return
            }
            
            // Shift pattern table registers
            bgFetchState.patternShiftLow <<= 1
            bgFetchState.patternShiftHigh <<= 1
            
            // Shift attribute registers
            bgFetchState.attributeShiftLow <<= 1
            bgFetchState.attributeShiftHigh <<= 1
        }
        
        /// Gets the color for the current background pixel
        private func getBackgroundPixel() -> UInt8 {
            // If background rendering is disabled, return transparent
            if !registers.mask.contains(.showBackground) {
                return 0
            }
            
            // If we're in the left 8 pixels and left clipping is enabled, return transparent
            if cycle < 8 && !registers.mask.contains(.showBackgroundLeft8Pixels) {
                return 0
            }
            
            // Get the bit position from fine X scroll
            let bitMux: UInt16 = 0x8000 >> registers.fineXScroll
            
            // Get pattern bits from shift registers
            let pixelLow: UInt8 = (bgFetchState.patternShiftLow & bitMux) > 0 ? 1 : 0
            let pixelHigh: UInt8 = (bgFetchState.patternShiftHigh & bitMux) > 0 ? 2 : 0
            
            // If pattern bits are 0, the pixel is transparent
            if (pixelLow | pixelHigh) == 0 {
                return 0
            }
            
            // Get palette bits from attribute shift registers
            let attrBitPos = 7 - registers.fineXScroll
            let paletteLow: UInt8 = (bgFetchState.attributeShiftLow >> attrBitPos) & 0x01
            let paletteHigh: UInt8 = (bgFetchState.attributeShiftHigh >> attrBitPos) & 0x01
            
            // Combine pattern and palette bits to get the palette entry
            // Format: 0bPPpp where PP is palette number and pp is pixel value
            let paletteIndex = (paletteHigh << 3) | (paletteLow << 2) | pixelHigh | pixelLow
            
            return paletteIndex
        }
        
        /// Updates shift registers during rendering and outputs pixels
        private func renderPixel() {
            // Get the background pixel
            let bgPixel = getBackgroundPixel()
            
            // TODO: Combine with sprite pixel
            
            // For now, just use the background pixel
            if cycle >= 1 && cycle <= 256 && scanline >= 0 && scanline < 240 {
                let x = cycle - 1
                let y = scanline
                
                // Use palette 0 for now (will be updated with proper palette selection)
                let colorIndex = memory.readPalette(from: 0x3F00 + UInt16(bgPixel))
                let color = colorFromPaletteIndex(colorIndex)
                
                frameBuffer.setPixel(x: x, y: y, color: color)
            }
            
            // Shift registers after outputting the pixel
            shiftBackgroundRegisters()
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

extension NES.PPU {
    // MARK: - Public API Functions
    
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
}
