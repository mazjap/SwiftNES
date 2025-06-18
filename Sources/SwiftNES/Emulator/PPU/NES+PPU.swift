extension NES {
    public class PPU {
        public var registers: Registers
        @BoundInteger<UInt16>(range: 0...340) public var cycle = 0
        @BoundInteger<UInt16>(range: 0...261) public var scanline = 0
        internal(set) public var frame: UInt
        public var isOddFrame: Bool // Used for skipped cycle on odd frames
        public var memoryManager: MMU
        public var nmiPending: Bool
        public var triggerNMI: () -> Void
        public var bgFetchState: BackgroundFetchState
        public var frameBuffer: FrameBuffer
        public var secondaryOAM: SecondaryOAM
        public var spriteData: [SpriteData]
        public var spriteFetchState: SpriteFetchState
        public var isDoingDebugRender = false
        
        // TODO: - Solidify Result Error type to specific cases
        var frameCallback: ((Result<Frame, Error>) -> Void)?
        public internal(set) var renderState: RenderState = .idle
       
        @_optimize(none)
        init(cartridge: Cartridge?, triggerNMI: @escaping () -> Void) {
            let memoryManager = MMU()
            
            self.registers = Registers(
                memoryManager: memoryManager,
                ctrl: .init(rawValue: 0),
                mask: .init(rawValue: 0),
                status: .vblank,
                oamAddr: 0,
                scroll: 0,
                addr: 0
            )
            self.cycle = 0
            self.scanline = 0
            self.frame = 0
            self.isOddFrame = false
            self.memoryManager = memoryManager
            self.nmiPending = false
            self.triggerNMI = triggerNMI
            self.bgFetchState = BackgroundFetchState()
            self.frameBuffer = FrameBuffer()
            self.secondaryOAM = SecondaryOAM()
            self.spriteData = Array(repeating: SpriteData(), count: 8)
            self.spriteFetchState = SpriteFetchState()
            
            self.reset(cartridge: cartridge)
        }
        
        // MARK: - Internal Functions
        
        func step() {
            switch (scanline, cycle) {
            case (0..<240, 0):
                bgFetchState.reset()
            case (0..<240, 1...256):
                // Visible pixels + tile/sprite fetching
                renderState = .visible
                
                if isDoingDebugRender {
                    renderPixelWithDebug()
                } else {
                    renderPixel()
                }
                
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
            case (0..<240, 257...320):
                renderState = .spriteEval
                updateSpriteEvaluation()
                
                if cycle == 257 {
                    // Copy horizontal scroll bits
                    updateAddressDuringRendering()
                }
            case (0..<240, 321...336):
                renderState = .prefetch
                fetchBackgroundTile() // ✅ ADD THIS - prefetch tiles
                
                if cycle == 328 || cycle == 336 {
                    incrementHorizontalPosition()
                }
            case (0..<240, 337...340):
                renderState = .idle
            case (241, 1):
                renderState = .idle
                registers.status.insert(.vblank)
                outputFrame()
                // Don't trigger NMI yet, just set pending
                nmiPending = true
            case (241, 3):
                if nmiPending && registers.ctrl.contains(.generateNMI) {
                    // Actually trigger the NMI if it wasn't suppressed
                    triggerNMI()
                }
            case (261, 1):
                registers.status.remove([.vblank, .sprite0Hit, .spriteOverflow])
                nmiPending = false
                bgFetchState.reset()
            case (261, 257...320):
                renderState = .spriteEval
                updateSpriteEvaluation()
                
                if cycle == 257 {
                    updateAddressDuringRendering()
                }
            case (261, 280...304):
                // Copy vertical scroll bits from temp to current
                updateAddressDuringRendering()
            case (261, 321...336):
                renderState = .prefetch
                fetchBackgroundTile() // Prefetch for scanline 0
                
                if cycle == 328 || cycle == 336 {
                    incrementHorizontalPosition()
                }
            case (_, _):
                renderState = .idle
            }
            
            // Advance PPU state
            if _cycle.isAtUpperLimit {
                cycle = 0
                if _scanline.isAtUpperLimit {
                    scanline = 0
                    frame &+= 1
                    isOddFrame = !isOddFrame
                    
                    // Skip cycle 0 on odd frames when rendering is enabled
                    if isOddFrame && (registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites)) {
                        cycle = 1
                    }
                } else {
                    scanline += 1
                }
            } else {
                cycle += 1
            }
        }
        
        func reset(cartridge: Cartridge?) {
            registers.reset()
            memoryManager.reset(cartridge: cartridge)
            
            bgFetchState.reset()
            secondaryOAM.clear()
            for i in 0..<spriteData.count {
                spriteData[i].reset()
            }
            spriteFetchState.reset()
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
            // Save old values to detect important changes
            let oldValue: UInt8 = switch register {
                case 0x00: registers.ctrl.rawValue
                case 0x01: registers.mask.rawValue
                default: 0
            }
            
            let isRenderingActive = (scanline >= 0 && scanline < 240) && (registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites))
            
            // Special handling for PPUCTRL (NMI generation)
            if register == 0x00 {
                writeControl(value)
            } else {
                // Standard register write
                registers.write(value, to: register)
            }
            
            // Handle mid-frame register effects
            guard isRenderingActive else { return }
            
            switch register {
            case 0x00: // PPUCTRL
                // Handle nametable selection changes
                if (value & 0x03) != (oldValue & 0x03) && cycle >= 1 && cycle <= 256 {
                    let nameTableBits = UInt16(value & 0x03) << 10
                    registers.currentVramAddress = (registers.currentVramAddress & 0xF3FF) | nameTableBits
                }
                
                // Changes to sprite size or pattern tables take effect immediately for subsequent sprite evaluations
            case 0x01: // PPUMASK
                let enabledBgBefore = (oldValue & 0x08) != 0
                let enabledBgAfter = (value & 0x08) != 0
                
                if enabledBgBefore != enabledBgAfter {
                    // Immediately changing background rendering during a frame
                    // can cause various glitches/artifacts on real hardware
                    
                    // For example, turning off background mid-scanline can
                    // make the rest of the scanline show universal background color
                }
                
                let enabledSpritesBefore = (oldValue & 0x10) != 0
                let enabledSpritesAfter = (value & 0x10) != 0
                
                if enabledSpritesBefore != enabledSpritesAfter {
                    // Similar effects for sprites
                    // For highly accurate emulation, track when rendering is enabled/disabled
                    // and adjust the scanline rendering accordingly
                }
            case 0x05, 0x06: // PPUSCROLL, PPUADDR
                // These can cause corruption to the internal state when written during rendering
                // TODO: - (Implement for high accuracy)
                break
            default: break
            }
        }
        
        // MARK: - public Functions
        
        public func colorFromPaletteIndex(_ index: UInt8) -> UInt32 {
            Self.masterPalette[Int(index & 0x3F)]
        }
        
        public func outputFrame() {
            guard let frameCallback else { return }
            frameCallback(.success(frameBuffer.makeFrame()))
        }
        
        public func incrementHorizontalPosition() {
            guard registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites) else { return }
            
            // Increment coarse X
            if (registers.currentVramAddress & 0x001F) == 31 {
                // If coarse X == 31, wrap to next nametable
                registers.currentVramAddress &= ~0x001F // Clear coarse X
                registers.currentVramAddress ^= 0x0400 // Switch horizontal nametable
            } else {
                registers.currentVramAddress += 1 // Increment coarse X
            }
        }

        public func incrementVerticalPosition() {
            guard registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites) else { return }
            
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
        public func updateAddressDuringRendering() {
            // Only update if rendering is enabled
            guard registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites) else { return }
            
            // At cycle 257, copy horizontal bits from t to v
            if cycle == 257 {
                // Copy horizontal bits from t to v (coarse X, nametable select X)
                registers.currentVramAddress = (registers.currentVramAddress & ~0x041F) | (registers.tempVramAddress & 0x041F)
            }
            
            // During pre-render scanline (261), copy vertical bits from t to v
            if scanline == 261 {
                if cycle == 0 {
                    bgFetchState.reset()
                } else if 280...304 ~= cycle { // Between cycles 280-304, copy vertical bits
                    // Copy vertical bits from t to v (coarse Y, fine Y, nametable select Y)
                    registers.currentVramAddress = (registers.currentVramAddress & ~0x7BE0) | (registers.tempVramAddress & 0x7BE0)
                }
            }
        }
        
        /// Performs background tile fetching based on current PPU cycle
        public func fetchBackgroundTile() {
            guard shouldFetchBackgroundTiles() else {
                emuLogger.warning("PPU's `fetchBackgroundTile()` called outside visible area! scanline \(self.scanline), cycle \(self.cycle)")
                return
            }
            
            // Only fetch during active rendering
            guard registers.mask.contains(.showBackground) else { return }
            
            // Get exact cycle within the 8-cycle sequence
            let fetchCycle = cycle & 0x7
            
            switch fetchCycle {
            case 1: // Nametable fetch
                bgFetchState.operation = .nametable
            case 2: // Second cycle of nametable fetch - data becomes available
                let nametableAddr = 0x2000 | (registers.currentVramAddress & 0x0FFF)
                bgFetchState.nametableByte = memoryManager.read(from: nametableAddr)
            case 3: // Attribute fetch
                bgFetchState.operation = .attribute
            case 4: // Second cycle of attribute fetch - data becomes available
                let v = registers.currentVramAddress
                let attributeAddr = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07)
                bgFetchState.attributeByte = memoryManager.read(from: attributeAddr)
                
                // Calculate attribute bits
                let shift = ((v >> 4) & 4) | (v & 2)
                bgFetchState.tileAttribute = (bgFetchState.attributeByte >> shift) & 0x3
            case 5: // Pattern low byte fetch
                bgFetchState.operation = .patternLow
            case 6: // Second cycle of pattern low byte fetch - data becomes available
                let patternAddr = registers.ctrl.backgroundPatternTableBaseAddress | (UInt16(bgFetchState.nametableByte) << 4) | ((registers.currentVramAddress >> 12) & 7)
                bgFetchState.patternLowByte = memoryManager.read(from: patternAddr)
            case 7: // Pattern high byte fetch
                bgFetchState.operation = .patternHigh
            case 0: // Second cycle of pattern high byte (cycle 8/0) - data becomes available
                let patternAddr = registers.ctrl.backgroundPatternTableBaseAddress | (UInt16(bgFetchState.nametableByte) << 4) | ((registers.currentVramAddress >> 12) & 7) | 8
                bgFetchState.patternHighByte = memoryManager.read(from: patternAddr)
                
                // Load shift registers at end of sequence
                loadBackgroundShiftRegisters()
            default:
                break // Should never happen
            }
        }
        
        /// Loads the shift registers with new tile data at the end of each fetch cycle
        public func loadBackgroundShiftRegisters() {
            // Shift existing data left by 8 and load new data into low byte
            bgFetchState.patternShiftLow = (bgFetchState.patternShiftLow << 8) | UInt16(bgFetchState.patternLowByte)
            bgFetchState.patternShiftHigh = (bgFetchState.patternShiftHigh << 8) | UInt16(bgFetchState.patternHighByte)
            
            // Convert attribute bits to bytes for the next 8 pixels
            let attrByteLow: UInt8 = (bgFetchState.tileAttribute & 0b01) != 0 ? 0xFF : 0x00
            let attrByteHigh: UInt8 = (bgFetchState.tileAttribute & 0b10) != 0 ? 0xFF : 0x00
            
            // Shift existing attribute data left by 8 and load new data
            bgFetchState.attributeShiftLow = (bgFetchState.attributeShiftLow << 8) | attrByteLow
            bgFetchState.attributeShiftHigh = (bgFetchState.attributeShiftHigh << 8) | attrByteHigh
        }
        
        /// Handle PPUSTATUS register read with proper NMI timing
        public func readStatus() -> UInt8 {
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
        public func writeControl(_ value: UInt8) {
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
        public func shiftBackgroundRegisters() {
            guard registers.mask.contains(.showBackground) else {
                return
            }
            
            // Shift all registers one bit left each cycle
            bgFetchState.patternShiftLow <<= 1
            bgFetchState.patternShiftHigh <<= 1
            bgFetchState.attributeShiftLow <<= 1
            bgFetchState.attributeShiftHigh <<= 1
        }
        
        /// Gets the color for the current background pixel
        public func getBackgroundPixel() -> UInt8 {
            guard shouldRenderPixels() else {
                emuLogger.warning("PPU's `getBackgroundPixel()` called outside visible area! scanline \(self.scanline), cycle \(self.cycle)")
                return 0
            }
            
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
            // Use bit 7 of the shift register (the bit that's about to shift out)
            let paletteLow: UInt8 = (bgFetchState.attributeShiftLow & 0x80) != 0 ? 1 : 0
            let paletteHigh: UInt8 = (bgFetchState.attributeShiftHigh & 0x80) != 0 ? 1 : 0
            
            // Combine pattern and palette bits to get the palette entry
            // Format: 0bPPpp where PP is palette number and pp is pixel value
            let paletteIndex = (paletteHigh << 3) | (paletteLow << 2) | pixelHigh | pixelLow
            
            return paletteIndex
        }
        
        public func renderPixelWithDebug() {
            guard shouldRenderPixels() else { return }
            
            let x = cycle - 1
            let y = scanline
            
            // Debug specific pixels
            let shouldDebugThisPixel = (y == 50 && x % 50 == 0) // Debug every 50th pixel on scanline 50
            
            if shouldDebugThisPixel {
                print("\n🔍 DEBUG PIXEL (\(x), \(y)):")
            }
            
            // Get the background pixel
            let bgPixel = getBackgroundPixel()
            let bgPaletteIndex = bgPixel & 0x0F
            let bgIsOpaque = bgPaletteIndex % 4 != 0
            
            if shouldDebugThisPixel {
                print("  Background: palette=\(bgPaletteIndex), opaque=\(bgIsOpaque)")
            }
            
            // Sprite processing with debug
            var spritePixel: UInt8 = 0
            var spritePalette: UInt8 = 0
            var spriteIsBehind: Bool = false
            var isSpriteZeroHit: Bool = false
            
            if registers.mask.contains(.showSprites) && (cycle > 8 || registers.mask.contains(.showSpritesLeft8Pixels)) {
                
                // Debug active sprites at this pixel
                if shouldDebugThisPixel {
                    print("  Active sprites:")
                    for i in 0..<spriteData.count {
                        if spriteData[i].active {
                            print("    Sprite \(i): XCounter=\(spriteData[i].xCounter)")
                        }
                    }
                }
                
                // Decrement X counters for ALL sprites
                for i in 0..<spriteData.count {
                    if spriteData[i].active && spriteData[i].xCounter > 0 {
                        spriteData[i].xCounter -= 1
                    }
                }
                
                // Check for sprite pixels
                for i in 0..<spriteData.count {
                    if !spriteData[i].active { continue }
                    
                    if spriteData[i].xCounter == 0 {
                        if let colorIndex = spriteData[i].getColorIndex() {
                            spritePixel = colorIndex
                            spritePalette = 4 + (spriteData[i].attributes & 0x03)
                            spriteIsBehind = (spriteData[i].attributes & 0x20) != 0
                            
                            if shouldDebugThisPixel {
                                print("  Sprite \(i) RENDERING: color=\(colorIndex), palette=\(spritePalette)")
                            }
                            
                            if spriteData[i].isSprite0 && bgIsOpaque &&
                               cycle != 255 && registers.mask.contains(.showBackground) {
                                isSpriteZeroHit = true
                            }
                            
                            break
                        }
                    }
                }
                
                // Shift sprite patterns
                for i in 0..<spriteData.count {
                    if spriteData[i].active && spriteData[i].xCounter == 0 {
                        spriteData[i].shift()
                    }
                }
            }
            
            // Final pixel determination
            var paletteIndex: UInt8
            
            if !registers.mask.contains(.showBackground) && !registers.mask.contains(.showSprites) {
                paletteIndex = 0
            } else if spritePixel == 0 {
                paletteIndex = bgPaletteIndex
            } else if !bgIsOpaque {
                paletteIndex = (spritePalette << 2) | spritePixel
            } else {
                if spriteIsBehind {
                    paletteIndex = bgPaletteIndex
                } else {
                    paletteIndex = (spritePalette << 2) | spritePixel
                }
            }
            
            if shouldDebugThisPixel {
                print("  Final palette index: \(paletteIndex)")
            }
            
            // Rest of rendering...
            let paletteAddr = 0x3F00 + UInt16(paletteIndex)
            let colorIndex = memoryManager.readPalette(from: paletteAddr)
            let finalColorIndex = registers.mask.contains(.greyscale) ? colorIndex & 0x30 : colorIndex
            let color = applyColorEmphasis(colorFromPaletteIndex(finalColorIndex))
            
            frameBuffer.setPixel(x: x, y: y, color: color)
            shiftBackgroundRegisters()
        }
        
        /// Gets the appropriate pixel color based on background and sprite data,
        /// handling sprite transparency and priority.
        public func renderPixel() {
            guard shouldRenderPixels() else {
                emuLogger.error("PPU's `renderPixel()` called outside visible area! scanline \(self.scanline), cycle \(self.cycle)")
                return
            }
            
            // Get the background pixel
            let bgPixel = getBackgroundPixel()
            let bgPaletteIndex = bgPixel & 0x0F // 4 bits: palette entry within a palette
            let bgIsOpaque = bgPaletteIndex % 4 != 0 // Background is opaque if not using color 0 of its palette
            
            // Get the sprite pixel (if any)
            var spritePixel: UInt8 = 0
            var spritePalette: UInt8 = 0
            var spriteIsBehind: Bool = false
            var isSpriteZeroHit: Bool = false
            
            // Only process sprites if they're enabled
            if registers.mask.contains(.showSprites) && (cycle > 8 || registers.mask.contains(.showSpritesLeft8Pixels)) {
                for i in 0..<spriteData.count {
                    if spriteData[i].active && spriteData[i].xCounter > 0 {
                        spriteData[i].xCounter -= 1
                    }
                }
                
                for i in 0..<spriteData.count {
                    if !spriteData[i].active { continue }
                    
                    // Only render if the sprite has reached its X position (counter = 0)
                    if spriteData[i].xCounter == 0 {
                        // Get the sprite pixel color index (0-3)
                        if let colorIndex = spriteData[i].getColorIndex() {
                            // Non-transparent sprite pixel found
                            spritePixel = colorIndex
                            
                            // Sprite palette is in bits 0-1 of the attribute byte
                            // Sprite palettes are stored at $3F10-$3F1F (palette indices 4-7)
                            spritePalette = 4 + (spriteData[i].attributes & 0x03)
                            
                            // Priority is in bit 5 of the attribute byte (0: in front of background, 1: behind background)
                            spriteIsBehind = (spriteData[i].attributes & 0x20) != 0
                            
                            // Check if this is sprite 0 for hit detection
                            if spriteData[i].isSprite0 && bgIsOpaque &&
                               cycle != 255 && // No sprite 0 hit on last visible pixel
                               registers.mask.contains(.showBackground) {
                                // Sprite 0 hit occurs when a non-zero pixel of sprite 0 overlaps
                                // with a non-zero pixel of the background
                                isSpriteZeroHit = true
                            }
                            
                            // Stop at the first non-transparent pixel (sprites are already in priority order)
                            break
                        }
                    }
                }
                
                for i in 0..<spriteData.count {
                    if spriteData[i].active && spriteData[i].xCounter == 0 {
                        spriteData[i].shift()
                    }
                }
            }
            
            // Sprite 0 hit detection (don't set if within the left 8 pixels and clipping is enabled)
            if isSpriteZeroHit &&
               !(cycle <= 8 && !registers.mask.contains(.showSpritesLeft8Pixels)) &&
               !registers.status.contains(.sprite0Hit) {
                registers.status.insert(.sprite0Hit)
            }
            
            // Determine the final pixel color
            let x = cycle - 1
            let y = scanline
            var paletteIndex: UInt8
            
            if !registers.mask.contains(.showBackground) && !registers.mask.contains(.showSprites) {
                // If both background and sprites are disabled, show the universal background color
                paletteIndex = 0  // $3F00 is the universal background color
            } else if spritePixel == 0 {
                // No sprite pixel, use background
                paletteIndex = bgPaletteIndex
            } else if !bgIsOpaque {
                // Transparent background, use sprite
                paletteIndex = (spritePalette << 2) | spritePixel
            } else {
                // Both sprite and background are opaque, use priority bit
                if spriteIsBehind {
                    paletteIndex = bgPaletteIndex
                } else {
                    paletteIndex = (spritePalette << 2) | spritePixel
                }
            }
            
            // Final address in palette RAM
            let paletteAddr = 0x3F00 + UInt16(paletteIndex)
            let colorIndex = memoryManager.readPalette(from: paletteAddr)
            
            // Apply grayscale mode if enabled
            let finalColorIndex = registers.mask.contains(.greyscale) ? colorIndex & 0x30 : colorIndex
            
            // Apply color emphasis if enabled
            let color = applyColorEmphasis(colorFromPaletteIndex(finalColorIndex))
            
            frameBuffer.setPixel(x: x, y: y, color: color)
            
            // Shift background registers after outputting the pixel
            shiftBackgroundRegisters()
        }
        
        /// Evaluates which sprites will be visible on the next scanline and populates secondary OAM
        /// Enforces the 8 sprite per scanline limit and handles overflow flag
        public func evaluateSpritesForNextScanline() {
            guard shouldEvaluateSprites() else {
                    emuLogger.error("PPU's `evaluateSpritesForNextScanline()` called outside visible area! scanline \(self.scanline), cycle \(self.cycle)")
                    return
                }
                
                // Clear secondary OAM for the new scanline
                secondaryOAM.clear()
                
                // Determine the target scanline (next scanline, or 0 for pre-render)
                let targetScanline = scanline == 261 ? 0 : scanline + 1
                
                // Determine sprite height based on current sprite size flag
                let spriteHeight = registers.ctrl.contains(.spriteSize) ? 16 : 8
                
                // Sprite overflow flag starts cleared
                registers.status.remove(.spriteOverflow)
                
                print("🔍 Evaluating sprites for scanline \(targetScanline), height=\(spriteHeight)")
                
                // Evaluate all 64 sprites in primary OAM
                var spriteCount = 0
                
                for spriteIndex in 0..<64 {
                    let oamBase = spriteIndex * 4
                    
                    // Read sprite data from OAM
                    let spriteY = memoryManager.readOAM(from: UInt8(oamBase))
                    let tileIndex = memoryManager.readOAM(from: UInt8(oamBase + 1))
                    let attributes = memoryManager.readOAM(from: UInt8(oamBase + 2))
                    let spriteX = memoryManager.readOAM(from: UInt8(oamBase + 3))
                    
                    // CRITICAL FIX: Correct NES sprite Y positioning logic
                    // On NES, sprite Y position is where the BOTTOM of the sprite will be
                    // So a sprite with Y=127 will have its bottom edge on scanline 127
                    // and its top edge on scanline (127 - spriteHeight + 1)
                    
                    let spriteTopScanline = Int(spriteY) + 1 - spriteHeight
                    let spriteBottomScanline = Int(spriteY)
                    
                    // Check if target scanline intersects with this sprite
                    let isVisible = targetScanline >= spriteTopScanline && targetScanline <= spriteBottomScanline
                    
                    if spriteIndex < 4 { // Debug first few sprites
                        print("  Sprite \(spriteIndex): Y=\(spriteY), X=\(spriteX)")
                        print("    Range: scanlines \(spriteTopScanline)-\(spriteBottomScanline)")
                        print("    Visible on \(targetScanline): \(isVisible)")
                    }
                    
                    if isVisible {
                        // Try to add the sprite to secondary OAM
                        let wasAdded = secondaryOAM.addSprite(
                            y: spriteY,
                            tile: tileIndex,
                            attributes: attributes,
                            x: spriteX,
                            isSprite0: spriteIndex == 0
                        )
                        
                        if wasAdded {
                            spriteCount += 1
                            print("  ✅ Added sprite \(spriteIndex) to secondary OAM (X=\(spriteX))")
                        } else {
                            // Hit the 8 sprite limit - set overflow flag
                            registers.status.insert(.spriteOverflow)
                            print("  ⚠️  Sprite overflow at sprite \(spriteIndex)")
                            break
                        }
                    }
                }
                
                print("🎯 Found \(spriteCount) sprites for scanline \(targetScanline)")
        }
        
        /// Integrate sprite evaluation into the PPU cycle processing
        public func updateSpriteEvaluation() {
            guard shouldEvaluateSprites() else {
                emuLogger.error("PPU's `updateSpriteEvaluation()` called outside visible area! scanline \(self.scanline), cycle \(self.cycle)")
                return
            }
            
            if cycle == 257 {
                // Start of sprite evaluation for next scanline
                evaluateSpritesForNextScanline()
                renderState = .spriteEval
                
                // Reset sprite fetch state for the new sprite evaluation phase
                spriteFetchState.reset()
                
                // Reset all sprite data for the next scanline
                for i in 0..<spriteData.count {
                    spriteData[i].reset()
                }
            } else if cycle >= 257 && cycle <= 320 {
                // Sprite pattern fetching (cycles 257-320)
                // Each sprite takes 8 cycles to fetch data
                fetchSpriteData()
            }
        }
        
        public func debugCurrentEvaluationFailure() {
            print("🐛 DEBUGGING CURRENT EVALUATION FAILURE")
            
            let targetScanline = scanline == 261 ? 0 : scanline + 1
            let spriteHeight = 8
            
            // Test the current (broken) logic vs fixed logic
            let sprite0Y = memoryManager.readOAM(from: 0)
            
            print("Sprite 0 Y position: \(sprite0Y)")
            print("Target scanline: \(targetScanline)")
            print("Sprite height: \(spriteHeight)")
            
            // Current (broken) logic from your code:
            let currentLogicSpriteRow = targetScanline - Int(sprite0Y) - 1
            let currentLogicVisible = currentLogicSpriteRow >= 0 && currentLogicSpriteRow < spriteHeight
            
            print("\nCURRENT (BROKEN) LOGIC:")
            print("  spriteRow = \(targetScanline) - \(sprite0Y) - 1 = \(currentLogicSpriteRow)")
            print("  visible = \(currentLogicSpriteRow) >= 0 && \(currentLogicSpriteRow) < \(spriteHeight) = \(currentLogicVisible)")
            
            // Fixed logic:
            let fixedTopScanline = Int(sprite0Y) + 1 - spriteHeight
            let fixedBottomScanline = Int(sprite0Y)
            let fixedVisible = targetScanline >= fixedTopScanline && targetScanline <= fixedBottomScanline
            
            print("\nFIXED LOGIC:")
            print("  spriteTopScanline = \(sprite0Y) + 1 - \(spriteHeight) = \(fixedTopScanline)")
            print("  spriteBottomScanline = \(sprite0Y)")
            print("  visible = \(targetScanline) >= \(fixedTopScanline) && \(targetScanline) <= \(fixedBottomScanline) = \(fixedVisible)")
            
            if currentLogicVisible != fixedVisible {
                print("\n🚨 LOGIC DIFFERENCE DETECTED!")
                print("   Current logic says: \(currentLogicVisible)")
                print("   Fixed logic says: \(fixedVisible)")
                print("   This explains why sprites aren't being evaluated!")
            }
        }
        
        /// Performs the sprite data fetching for the current cycle
        public func fetchSpriteData() {
            // Skip if sprites are disabled
            guard registers.mask.contains(.showSprites) else { return }
            
            // Calculate which sprite is being fetched and which operation within that sprite's fetch
            let spriteIndex = (cycle - 257) / 8
            let fetchCycle = (cycle - 257) % 8
            
            // Update state to match the current cycle
            spriteFetchState.currentSprite = spriteIndex
            spriteFetchState.fetchCycle = fetchCycle
            
            switch fetchCycle {
            case 0: // First cycle - Garbage NT fetch, load sprite attributes
                spriteFetchState.operation = .garbageNT
                
                // If we have this sprite in secondary OAM, load its data for fetching
                if spriteIndex < secondaryOAM.sprites.count {
                    let sprite = secondaryOAM.sprites[spriteIndex]
                    spriteFetchState.tileIndex = sprite.tile
                    spriteFetchState.attributes = sprite.attributes
                    spriteFetchState.xPosition = sprite.x
                    spriteFetchState.yPosition = sprite.y
                    spriteFetchState.isSprite0 = spriteIndex == 0 && secondaryOAM.sprite0Present
                    
                    // Calculate which row of the sprite we need
                    let targetScanline = scanline == 261 ? 0 : scanline + 1
                    var spriteRow = targetScanline - Int(sprite.y) - 1
                    
                    // Handle vertical flipping
                    if (sprite.attributes & 0x80) != 0 {
                        if registers.ctrl.contains(.spriteSize) {
                            // 8x16 sprites
                            spriteRow = 15 - spriteRow
                        } else {
                            // 8x8 sprites
                            spriteRow = 7 - spriteRow
                        }
                    }
                    
                    spriteFetchState.spriteRowY = spriteRow
                    
                    // Calculate pattern table address
                    if registers.ctrl.contains(.spriteSize) {
                        // 8x16 sprites: bit 0 of tile index selects pattern table
                        let tableSelect: UInt16 = (sprite.tile & 0x01) == 0 ? 0x0000 : 0x1000
                        
                        // Use top or bottom half of sprite based on row
                        var tileIndexBase = UInt16(sprite.tile & 0xFE)
                        
                        // Select top or bottom tile
                        if spriteRow >= 8 {
                            tileIndexBase += 1
                            spriteRow -= 8
                        }
                        
                        spriteFetchState.patternTableAddress = tableSelect + tileIndexBase * 16 + UInt16(spriteRow)
                    } else {
                        // 8x8 sprites
                        let patternTableAddress: UInt16 = registers.ctrl.contains(.spritePatternTableAddress) ? 0x1000 : 0x0000
                        spriteFetchState.patternTableAddress = patternTableAddress + UInt16(sprite.tile) * 16 + UInt16(spriteRow)
                    }
                }
                
            case 1: // Second cycle - Garbage NT fetch completes
                // The real PPU doesn't do anything useful with this data
                spriteFetchState.operation = .garbageNT
                
            case 2: // Third cycle - Garbage AT fetch
                spriteFetchState.operation = .garbageAT
                
            case 3: // Fourth cycle - Garbage AT fetch completes
                // The real PPU doesn't do anything useful with this data
                spriteFetchState.operation = .garbageAT
                
            case 4: // Fifth cycle - Pattern table low byte fetch
                spriteFetchState.operation = .patternLow
                
            case 5: // Sixth cycle - Pattern table low byte fetch completes
                // Read the low byte of the pattern
                if spriteIndex < secondaryOAM.sprites.count {
                    spriteFetchState.patternLowByte = memoryManager.read(from: spriteFetchState.patternTableAddress)
                }
                
            case 6: // Seventh cycle - Pattern table high byte fetch
                spriteFetchState.operation = .patternHigh
                
            case 7: // Eighth cycle - Pattern table high byte fetch completes, load to sprite shift registers
                // Read the high byte of the pattern
                if spriteIndex < secondaryOAM.sprites.count {
                    spriteFetchState.patternHighByte = memoryManager.read(from: spriteFetchState.patternTableAddress + 8)
                    
                    // Store the completed sprite data in our sprite data array
                    spriteData[spriteIndex] = SpriteData(
                        patternLow: spriteFetchState.patternLowByte,
                        patternHigh: spriteFetchState.patternHighByte,
                        attributes: spriteFetchState.attributes,
                        x: spriteFetchState.xPosition,
                        isSprite0: spriteFetchState.isSprite0,
                        active: true
                    )
                }
                
            default:
                break // Should never happen
            }
        }
        
        /// Applies color emphasis bits to the specified color
        /// - Parameter color: The original RGB color
        /// - Returns: The modified color with emphasis applied
        public func applyColorEmphasis(_ color: UInt32) -> UInt32 {
            // If no emphasis bits are set, return the original color
            if !registers.mask.contains([.emphasizeRed, .emphasizeGreen, .emphasizeBlue]) {
                return color
            }
            
            // Extract RGB components
            let r = (color >> 16) & 0xFF
            let g = (color >> 8) & 0xFF
            let b = color & 0xFF
            
            // Apply emphasis - the real hardware attenuates the non-emphasized colors by about 15-20%
            var newR = r
            var newG = g
            var newB = b
            
            if !registers.mask.contains(.emphasizeRed) {
                newR = UInt32(Float(r) * 0.8)
            }
            
            if !registers.mask.contains(.emphasizeGreen) {
                newG = UInt32(Float(g) * 0.8)
            }
            
            if !registers.mask.contains(.emphasizeBlue) {
                newB = UInt32(Float(b) * 0.8)
            }
            
            // Combine components back into a single color
            return (newR << 16) | (newG << 8) | newB
        }
        
        public static let masterPalette: [UInt32] = [
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
    @inline(__always)
    public func isVisibleScanline() -> Bool {
        0..<240 ~= scanline
    }
    
    @inline(__always)
    public func isPreRenderScanline() -> Bool {
        scanline == 261
    }
    
    @inline(__always)
    public func isVisibleCycle() -> Bool {
        cycle >= 1 && cycle <= 256
    }
    
    @inline(__always)
    public func isPrefetchCycle() -> Bool {
        cycle >= 321 && cycle <= 336
    }
    
    @inline(__always)
    public func shouldRenderPixels() -> Bool {
        isVisibleScanline() && isVisibleCycle()
    }
    
    @inline(__always)
    public func shouldFetchBackgroundTiles() -> Bool {
        (isVisibleScanline() && (isVisibleCycle() || isPrefetchCycle())) ||
        (isPreRenderScanline() && isPrefetchCycle())
    }
    
    @inline(__always)
    public func shouldEvaluateSprites() -> Bool {
        (isVisibleScanline() || isPreRenderScanline())
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
