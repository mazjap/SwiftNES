extension NES {
    public class PPU {
        var registers: Registers
        var cycle: Int // 0-340 pixels per scanline
        var scanline: Int // 0-261 scanlines per frame
        var frame: Int
        var isOddFrame: Bool // Used for skipped cycle on odd frames
        var memoryManager: MMU
        var triggerNMI: () -> Void
        
        /// The NMI output level is (vblank flag AND PPUCTRL NMI enable). The CPU's
        /// NMI input is edge sensitive, so the line is asserted only on a
        /// false -> true transition of that level. This single rule covers vblank
        /// start, enabling NMI part-way through vblank, and re-enabling after a
        /// toggle, none of which need a special case of their own.
        private var previousNMIOutputLevel = false
        
        /// Set when $2002 is read on the cycle immediately before vblank would be
        /// set. On hardware the read and the set collide and the flag never gets
        /// set that frame, so no NMI occurs either.
        private var suppressVBlankThisFrame = false
        var bgFetchState: BackgroundFetchState
        var frameBuffer: FrameBuffer
        var secondaryOAM: SecondaryOAM
        var spriteData: [SpriteData]
        var spriteFetchState: SpriteFetchState
        
        // TODO: - Solidify Result Error type to specific cases
        var frameCallback: ((Result<Frame, Error>) -> Void)?
        public internal(set) var renderState: RenderState = .idle
        
        init(cartridge: Cartridge?, triggerNMI: @escaping () -> Void) {
            let memoryManager = MMU()
            
            self.registers = Registers(
                memoryManager: memoryManager,
                ctrl: .init(rawValue: 0),
                mask: .init(rawValue: 0),
                // `reset(cartridge:)` below clears status anyway; seeding vblank
                // here only made the starting state look deliberate when it wasn't
                status: .init(rawValue: 0),
                oamAddr: 0,
                scroll: 0,
                addr: 0
            )
            self.cycle = 0
            self.scanline = 0
            self.frame = 0
            self.isOddFrame = false
            self.memoryManager = memoryManager
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
            // Pre-render scanline - clear VBlank, sprite 0 hit, sprite overflow, and pending nmi interrupt
            if scanline == 261 && cycle == 1 {
                registers.status.remove([.vblank, .sprite0Hit, .spriteOverflow])
            }
            
            // Update VRAM address registers during rendering. Only cycle 257 and
            // the pre-render scanline can do anything here, so skip the call on the
            // ~99% of cycles that cannot.
            if cycle == 257 || scanline == 261 {
                updateAddressDuringRendering()
            }
            
            // Sprite evaluation and tile loading, cycles 257-320. Gated here as
            // well as inside, for the same reason as the address update above:
            // step() runs every cycle and this window is a fifth of a scanline.
            if cycle >= 257 && cycle <= 320 && isRenderingScanline {
                updateSpriteEvaluation()
            }
            
            // Active scanlines (0-239)
            if scanline >= 0 && scanline < 240 {
                if cycle == 0 {
                    // Idle cycle
                    renderState = .idle
                    bgFetchState.reset()
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
                } else {
                    // 257-320 sprite fetches (driven by updateSpriteEvaluation),
                    // 321-336 background prefetch for the next scanline,
                    // 337-340 the two dummy nametable fetches that close the line
                    if cycle <= 336 {
                        renderState = .prefetch
                    }
                    
                    runBackgroundPrefetch()
                }
            }
            
            if scanline == 261 {
                runBackgroundPrefetch()
            }
            
            // Start of VBlank (scanline 241)
            if scanline == 241 && cycle == 1 {
                renderState = .idle
                
                // A $2002 read on the cycle before this one collides with the flag
                // being set, and the flag loses — it never gets set this frame.
                if !suppressVBlankThisFrame {
                    registers.status.insert(.vblank)
                }
                suppressVBlankThisFrame = false
                
                outputFrame()
            }
            
            // The NMI line is sampled once per cycle; no register write or vblank
            // transition needs to trigger it explicitly.
            pollNMILine()
            
            // Advance PPU state
            cycle += 1
            
            // On odd frames with rendering enabled the pre-render scanline runs one
            // cycle short: (261, 339) jumps straight to (0, 0), so cycle 340 of the
            // pre-render line never happens.
            let renderingEnabled = registers.mask.contains(.showBackground)
            || registers.mask.contains(.showSprites)
            
            if scanline == 261 && cycle == 340 && isOddFrame && renderingEnabled {
                cycle = 0
                scanline = 0
                frame &+= 1
                isOddFrame = !isOddFrame
            } else if cycle > 340 {
                cycle = 0
                scanline += 1
                
                if scanline > 261 {
                    scanline = 0
                    frame &+= 1
                    isOddFrame = !isOddFrame
                }
            }
        }
        /// Returns the PPU to its power-on state.
        ///
        /// This is reached both from `init` and from `NES.load(cartridge:)`, so it
        /// has to put the chip at a known position in the frame, not just clear
        /// the fetch scaffolding.
        ///
        /// PPUSTATUS is cleared here. Actual Hardware leaves it unchanged across a
        /// reset but clears it at power-on, and since this method serves as power-on it
        /// takes the power-on behavior. Hopefully that doesn't cause issues.
        /// `Registers.reset()` leaves PPUSTATUS alone, like actual hardware.
        ///
        /// Note VRAM, OAM and palette RAM are intentionally not cleared.
        func reset(cartridge: Cartridge?) {
            registers.reset()
            registers.status = .init(rawValue: 0)
            memoryManager.reset(cartridge: cartridge)
            
            // Frame sequencing
            cycle = 0
            scanline = 0
            frame = 0
            isOddFrame = false
            renderState = .idle
            previousNMIOutputLevel = false
            suppressVBlankThisFrame = false
            
            // Don't leave the previous cartridge's last frame on screen
            frameBuffer = FrameBuffer()
            
            bgFetchState = BackgroundFetchState()
            
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
            
            registers.write(value, to: register)
            
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
        
        // MARK: - Private Functions
        
        /// The scanlines that run the rendering pipeline: the 240 visible lines
        /// plus the pre-render line. Scanline 240 and the vblank lines (241-260)
        /// are not rendering scanlines — being on one is an ordinary state, not
        /// an error condition.
        private var isRenderingScanline: Bool {
            (scanline >= 0 && scanline < 240) || scanline == 261
        }
        
        private func colorFromPaletteIndex(_ index: UInt8) -> UInt32 {
            Self.masterPalette[Int(index & 0x3F)]
        }
        
        private func outputFrame() {
            guard let frameCallback else { return }
            frameCallback(.success(frameBuffer.makeFrame()))
        }
        
        private func incrementHorizontalPosition() {
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
        
        private func incrementVerticalPosition() {
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
        ///
        /// `isRenderingScanline` matters as much as the mask here. Most games leave
        /// rendering enabled in PPUMASK during vblank and do their VRAM updates
        /// through $2007 then; without the scanline check the cycle 257 copy fired on
        /// every vblank scanline and reset the low bits of `v` mid-burst, so a run of
        /// writes kept looping back over the same few bytes.
        private func updateAddressDuringRendering() {
            guard isRenderingScanline,
                  registers.mask.contains(.showBackground) || registers.mask.contains(.showSprites)
            else { return }
            
            // At cycle 257, copy horizontal bits from t to v
            if cycle == 257 {
                // Copy horizontal bits from t to v (coarse X, nametable select X)
                registers.currentVramAddress = (registers.currentVramAddress & ~0x041F) | (registers.tempVramAddress & 0x041F)
            }
            
            // During pre-render scanline (261), copy vertical bits from t to v
            if scanline == 261 {
                if cycle == 0 {
                    bgFetchState.reset()
                } else if cycle >= 280 && cycle <= 304 { // Between cycles 280-304, copy vertical bits
                    // Copy vertical bits from t to v (coarse Y, fine Y, nametable select Y)
                    registers.currentVramAddress = (registers.currentVramAddress & ~0x7BE0) | (registers.tempVramAddress & 0x7BE0)
                }
            }
        }
        
        /// Fetches the first two tiles of the *next* scanline (cycles 321-336),
        /// together with the shifts and coarse-X increments that belong to them.
        private func runBackgroundPrefetch() {
            if cycle >= 321 && cycle <= 336 {
                if cycle >= 329 {
                    shiftBackgroundRegisters()
                }
                
                fetchBackgroundTile()
                
                // At 328 and 336, we need to increment the horizontal position
                if cycle == 328 || cycle == 336 {
                    incrementHorizontalPosition()
                }
            } else if cycle == 338 || cycle == 340 {
                // Two dummy nametable fetches close out the scanline. Nothing
                // consumes the bytes, but they are real bus activity — mappers that
                // watch PPU reads (MMC5, and MMC3's A12 counter) can see them, so
                // they have to happen even though they feed nothing here.
                guard registers.mask.contains(.showBackground)
                        || registers.mask.contains(.showSprites) else { return }
                
                _ = memoryManager.read(from: 0x2000 | (registers.currentVramAddress & 0x0FFF))
            }
        }
        
        /// Performs background tile fetching based on current PPU cycle
        ///
        /// - Precondition: only called from the two windows that fetch — cycles
        ///   1-256 of a visible scanline, and 321-336 of a visible or pre-render
        ///   scanline via `runBackgroundPrefetch()`. `step()` enforces that.
        private func fetchBackgroundTile() {
            // The fetch machinery runs whenever rendering is enabled, not only when
            // the background is being displayed — with the background hidden the
            // pixels are suppressed at output time, but the reads still happen.
            guard registers.mask.contains(.showBackground)
                    || registers.mask.contains(.showSprites) else { return }
            
            // Get exact cycle within the 8-cycle sequence
            let fetchCycle = cycle & 0x7
            
            // Each fetch spans two cycles; the data only lands on the second of
            // them, so only the even cycles do anything here.
            switch fetchCycle {
            case 2: // Second cycle of nametable fetch - data becomes available
                let nametableAddr = 0x2000 | (registers.currentVramAddress & 0x0FFF)
                bgFetchState.nametableByte = memoryManager.read(from: nametableAddr)
            case 4: // Second cycle of attribute fetch - data becomes available
                let v = registers.currentVramAddress
                let attributeAddr = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07)
                bgFetchState.attributeByte = memoryManager.read(from: attributeAddr)
                
                // Calculate attribute bits
                let shift = ((v >> 4) & 4) | (v & 2)
                bgFetchState.tileAttribute = (bgFetchState.attributeByte >> shift) & 0x3
            case 6: // Second cycle of pattern low byte fetch - data becomes available
                let patternAddr = registers.ctrl.backgroundPatternTableBaseAddress | (UInt16(bgFetchState.nametableByte) << 4) | ((registers.currentVramAddress >> 12) & 7)
                bgFetchState.patternLowByte = memoryManager.read(from: patternAddr)
            case 0: // Second cycle of pattern high byte (cycle 8/0) - data becomes available
                let patternAddr = registers.ctrl.backgroundPatternTableBaseAddress | (UInt16(bgFetchState.nametableByte) << 4) | ((registers.currentVramAddress >> 12) & 7) | 8
                bgFetchState.patternHighByte = memoryManager.read(from: patternAddr)
                
                // Load shift registers at end of sequence
                loadBackgroundShiftRegisters()
            default:
                break // First cycle of each fetch; the read completes next cycle
            }
        }
        
        /// Loads the shift registers with new tile data at the end of each fetch cycle
        ///
        /// The newly fetched tile goes into the **low** byte only; the high byte is
        /// left alone because it holds the tile currently being drawn. The eight
        /// shifts that happen before the next load walk this byte up into the high
        /// half, one pixel at a time, so it arrives at the output (bit 15) exactly
        /// when the tile in front of it has been consumed.
        ///
        /// Shifting the register by 8 here as well — as this used to — advances it
        /// by 16 bits per 8 pixels, flushing each byte straight back out before a
        /// single one of its bits ever reaches bit 15. That made every background
        /// pixel read as transparent.
        private func loadBackgroundShiftRegisters() {
            bgFetchState.patternShiftLow = (bgFetchState.patternShiftLow & 0xFF00) | UInt16(bgFetchState.patternLowByte)
            bgFetchState.patternShiftHigh = (bgFetchState.patternShiftHigh & 0xFF00) | UInt16(bgFetchState.patternHighByte)
            
            // The 2-bit attribute is expanded across the whole byte so every pixel
            // of the tile samples the same palette selection.
            let attrByteLow: UInt16 = (bgFetchState.tileAttribute & 0b01) != 0 ? 0x00FF : 0x0000
            let attrByteHigh: UInt16 = (bgFetchState.tileAttribute & 0b10) != 0 ? 0x00FF : 0x0000
            
            bgFetchState.attributeShiftLow = (bgFetchState.attributeShiftLow & 0xFF00) | attrByteLow
            bgFetchState.attributeShiftHigh = (bgFetchState.attributeShiftHigh & 0xFF00) | attrByteHigh
        }
        
        /// Handle PPUSTATUS register read with proper NMI timing
        private func readStatus() -> UInt8 {
            // Reading on the cycle immediately before vblank would be set races with
            // the set and wins: the flag never gets set this frame, and with it no
            // NMI. Note this is cycle 0 only — reading a cycle or two *after* the flag
            // is set does not retroactively suppress the NMI, it has already fired.
            if scanline == 241 && cycle == 0 {
                suppressVBlankThisFrame = true
            }
            
            let currentStatus = registers.status.readAndClear()
            registers.writeToggle = false
            
            return currentStatus
        }
        
        /// Samples the NMI output level and asserts the line on a rising edge.
        ///
        /// Called once per cycle. Replaces the two ad-hoc trigger sites this used to
        /// have — a hardcoded fire at scanline 241 cycle 3, and a second fire inside
        /// the PPUCTRL write path. Those could both run for the same vblank, so
        /// enabling NMI at cycle 2 of scanline 241 raised the line twice.
        private func pollNMILine() {
            let level = registers.status.contains(.vblank)
            && registers.ctrl.contains(.generateNMI)
            
            if level && !previousNMIOutputLevel {
                triggerNMI()
            }
            
            previousNMIOutputLevel = level
        }
        
        /// Shifts all background registers by one bit
        private func shiftBackgroundRegisters() {
            guard registers.mask.contains(.showBackground)
                    || registers.mask.contains(.showSprites) else {
                return
            }
            
            // Shift all registers one bit left each cycle
            bgFetchState.patternShiftLow <<= 1
            bgFetchState.patternShiftHigh <<= 1
            bgFetchState.attributeShiftLow <<= 1
            bgFetchState.attributeShiftHigh <<= 1
        }
        
        /// Gets the color for the current background pixel
        ///
        /// - Precondition: called only from `renderPixel()`, which runs on cycles
        ///   1-256 of visible scanlines. Runs once per pixel, so it carries no
        ///   range check of its own.
        private func getBackgroundPixel() -> UInt8 {
            // If background rendering is disabled, return transparent
            if !registers.mask.contains(.showBackground) {
                return 0
            }
            
            // Cycles 1...256 produce pixels x = 0...255
            let x = cycle - 1
            
            // If we're in the left 8 pixels and left clipping is enabled, return transparent
            if x < 8 && !registers.mask.contains(.showBackgroundLeft8Pixels) {
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
            
            // Get palette bits from the attribute shift registers, sampled at the
            // same position as the pattern bits so the palette selection tracks
            // the tile it belongs to (and follows fine X scrolling with it)
            let paletteLow: UInt8 = (bgFetchState.attributeShiftLow & bitMux) != 0 ? 1 : 0
            let paletteHigh: UInt8 = (bgFetchState.attributeShiftHigh & bitMux) != 0 ? 1 : 0
            
            // Combine pattern and palette bits to get the palette entry
            // Format: 0bPPpp where PP is palette number and pp is pixel value
            let paletteIndex = (paletteHigh << 3) | (paletteLow << 2) | pixelHigh | pixelLow
            
            return paletteIndex
        }
        
        /// Gets the appropriate pixel color based on background and sprite data,
        /// handling sprite transparency and priority.
        /// - Precondition: called only from `step()`, on cycles 1-256 of a visible
        ///   scanline. Runs once per pixel, so it carries no range check of its own.
        private func renderPixel() {
            // Cycles 1...256 produce pixels x = 0...255. Every position test below is
            // written against x rather than `cycle`, because the masks and the
            // sprite 0 hit rule are all defined in screen coordinates.
            let x = cycle - 1
            
            // Get the background pixel
            let bgPixel = getBackgroundPixel()
            let bgPaletteIndex = bgPixel & 0x0F // 4 bits: palette entry within a palette
            let bgIsOpaque = bgPaletteIndex % 4 != 0 // Background is opaque if not using color 0 of its palette
            
            // Get the sprite pixel (if any)
            var spritePixel: UInt8 = 0
            var spritePalette: UInt8 = 0
            var spriteIsBehind: Bool = false
            var isSpriteZeroHit: Bool = false
            
            // Both passes share one buffer scope: this runs once per visible pixel
            // (~61k times a frame), and `spriteData` is a stored array property, so
            // each `spriteData[i]` would otherwise be a separately bounds-checked
            // access with its own exclusivity check.
            let showSprites = registers.mask.contains(.showSprites)
            let spritesVisibleHere = showSprites
            && (x >= 8 || registers.mask.contains(.showSpritesLeft8Pixels))
            let showBackground = registers.mask.contains(.showBackground)
            
            if showSprites {
                spriteData.withUnsafeMutableBufferPointer { units in
                    // --- Pixel selection. Read-only: no unit is modified here, so
                    // which sprite wins the pixel cannot affect any other's state.
                    //
                    // `getColorIndex()` already returns nil for an inactive unit, a
                    // unit still counting down its X position, and a transparent pixel.
                    if spritesVisibleHere {
                        var i = 0
                        
                        // Lowest OAM index wins, so the first opaque pixel takes the dot
                        while i < units.count {
                            defer { i += 1 }
                            
                            guard let colorIndex = units[i].getColorIndex() else { continue }
                            
                            spritePixel = colorIndex
                            
                            // Sprite palette is in bits 0-1 of the attribute byte
                            // Sprite palettes live at $3F10-$3F1F (palette indices 4-7)
                            spritePalette = 4 + (units[i].attributes & 0x03)
                            
                            // Priority is bit 5 (0: in front of background, 1: behind)
                            spriteIsBehind = (units[i].attributes & 0x20) != 0
                            
                            if units[i].isSprite0 && bgIsOpaque
                                && x != 255 // No sprite 0 hit on the last visible pixel
                                && showBackground {
                                isSpriteZeroHit = true
                            }
                            
                            // Stop at the first non-transparent pixel
                            break
                        }
                    }
                    
                    // --- Per-dot state advance, kept strictly separate from selection.
                    // Every active unit advances on every dot: units still waiting on
                    // their X position count down, units that have reached it shift out
                    // the pixel just consumed.
                    //
                    // Deliberately not gated on the left-8 mask: a clipped sprite is
                    // hidden, not paused, so its pixel stream has to keep moving or it
                    // desynchronizes from its X position.
                    var j = 0
                    
                    while j < units.count {
                        defer { j += 1 }
                        
                        guard units[j].active else { continue }
                        
                        if units[j].xCounter > 0 {
                            units[j].xCounter -= 1
                        } else {
                            units[j].shift()
                        }
                    }
                }
            }
            
            // Sprite 0 hit detection (don't set if within the left 8 pixels and clipping is enabled)
            if isSpriteZeroHit &&
                !(x < 8 && !registers.mask.contains(.showSpritesLeft8Pixels)) &&
                !registers.status.contains(.sprite0Hit) {
                registers.status.insert(.sprite0Hit)
            }
            
            // Determine the final pixel color
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
        /// - Precondition: called only from `updateSpriteEvaluation()`, which is
        ///   itself gated on `isRenderingScanline`.
        private func evaluateSpritesForNextScanline() {
            // Clear secondary OAM for the new scanline
            secondaryOAM.clear()
            
            // Determine the target scanline (next scanline, or 0 for pre-render)
            let targetScanline = scanline == 261 ? 0 : scanline + 1
            
            // Determine sprite height based on current sprite size flag
            let spriteHeight = registers.ctrl.contains(.spriteSize) ? 16 : 8
            
            // Evaluate all 64 sprites in primary OAM
            var n = 0 // Primary OAM index (0-255)
            
            // Buggy sprite overflow implementation to match hardware bug
            var m = 0 // Sprite index in evaluation (0-63)
            var overflowBugCounter = 0 // For accurate overflow bug behavior
            var inOverflowMode = false // Track if we're in overflow evaluation mode
            
            // Check first 64 sprites
            while m < 64 {
                // Read Y coordinate from OAM
                let spriteY = memoryManager.readOAM(from: UInt8(n))
                
                // Check if this sprite is in range for the next scanline
                let spriteRow = targetScanline - Int(spriteY) - 1
                
                if spriteRow >= 0 && spriteRow < spriteHeight {
                    // Sprite is visible on the next scanline
                    
                    // Try to add the sprite to secondary OAM, respecting the 8 sprite limit
                    if !inOverflowMode {
                        let tileIndex = memoryManager.readOAM(from: UInt8(n + 1))
                        let attributes = memoryManager.readOAM(from: UInt8(n + 2))
                        let spriteX = memoryManager.readOAM(from: UInt8(n + 3))
                        
                        let wasAdded = secondaryOAM.addSprite(
                            y: spriteY,
                            tile: tileIndex,
                            attributes: attributes,
                            x: spriteX,
                            isSprite0: m == 0
                        )
                        
                        if !wasAdded {
                            // We've hit the 8 sprite limit - enter overflow mode and set the flag
                            registers.status.insert(.spriteOverflow)
                            inOverflowMode = true
                        }
                    } else {
                        // We're in overflow mode - set the overflow flag but don't add the sprite
                        registers.status.insert(.spriteOverflow)
                    }
                }
                
                // Increment sprite index
                m += 1
                n += 4
                
                // Hardware bug implementation:
                // After the 8th sprite, reuse the same n counter for address calculations
                // but don't actually write to secondary OAM
                if inOverflowMode {
                    // The hardware bug is complex - it increments n for every sprite tested
                    // but then incorrectly uses (n & 0x1F) as the low bits of the OAM address
                    // for the next evaluation, leading to comparing Y positions with sprite
                    // attribute/X data
                    overflowBugCounter += 1
                    
                    if overflowBugCounter == 3 {
                        // After 3 increments, the counter points to the next sprite's Y position
                        // In hardware, this makes the PPU incorrectly load from the next sprite's
                        // attribute byte instead of Y coordinate
                        // For simplicity, just break from the loop as the detection is already done
                        break
                    }
                }
            }
        }
        
        /// Integrate sprite evaluation into the PPU cycle processing
        ///
        /// Sprite work only happens on rendering scanlines. This used to log an
        /// error when it wasn't on one — but `step()` called it for all 341 dots
        /// of all 262 scanlines, so the 21 non-rendering lines (240 and 241-260)
        /// produced 7,161 error logs every frame. `.error` and `.warning` are
        /// persisted by the unified logging system, unlike `.debug`, so that
        /// alone accounted for roughly a quarter of the emulator's runtime.
        ///
        /// Being on a non-rendering scanline is a normal state, not a fault, so
        /// the caller now checks `isRenderingScanline` and this stays as a plain
        /// early return for anyone calling it directly.
        private func updateSpriteEvaluation() {
            guard isRenderingScanline else { return }
            
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
            }
            
            if cycle >= 257 && cycle <= 320 {
                // Hardware holds OAMADDR at 0 for the whole sprite tile loading
                // window. A game that leaves OAMADDR part-way into OAM and reads
                // $2004 during rendering sees entry 0, not wherever it left the
                // pointer.
                registers.oamAddr = 0
                
                // Sprite pattern fetching (cycles 257-320)
                // Each sprite takes 8 cycles to fetch data
                fetchSpriteData()
            }
        }
        
        /// Performs the sprite data fetching for the current cycle
        private func fetchSpriteData() {
            // Skip if sprites are disabled
            guard registers.mask.contains(.showSprites) else { return }
            
            // Calculate which sprite is being fetched and which operation within that sprite's fetch
            let spriteIndex = (cycle - 257) / 8
            let fetchCycle = (cycle - 257) % 8
            
            switch fetchCycle {
            case 0: // First cycle - Garbage NT fetch, load sprite attributes
                // If we have this sprite in secondary OAM, load its data for fetching
                if spriteIndex < secondaryOAM.sprites.count {
                    let sprite = secondaryOAM.sprites[spriteIndex]
                    spriteFetchState.attributes = sprite.attributes
                    spriteFetchState.xPosition = sprite.x
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
                
            case 5: // Sixth cycle - Pattern table low byte fetch completes
                // Read the low byte of the pattern
                if spriteIndex < secondaryOAM.sprites.count {
                    spriteFetchState.patternLowByte = memoryManager.read(from: spriteFetchState.patternTableAddress)
                }
                
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
                // Cycles 1-4 and 6 cover the garbage nametable/attribute fetches
                // and the first half of the pattern reads. The PPU discards all
                // of it, so there is nothing to model.
                break
            }
        }
        
        /// Applies color emphasis bits to the specified color
        /// - Parameter color: The original RGB color
        /// - Returns: The modified color with emphasis applied
        ///
        /// Runs once per pixel, and emphasis is off in almost every frame ever
        /// rendered, so only this test is inlined into `renderPixel` — the
        /// arithmetic stays outlined. Marking the whole function
        /// `@inline(__always)` measured ~1% slower, because it drags the Float
        /// attenuation math into the per-pixel path for a branch that is almost
        /// never taken.
        @inline(__always)
        private func applyColorEmphasis(_ color: UInt32) -> UInt32 {
            // `contains(_:)` on an OptionSet asks whether *all* of the given members
            // are present, so `!contains([red, green, blue])` was true for every
            // input except all three bits set — and in that one remaining case the
            // per-channel tests below each came out false and attenuated nothing.
            // Emphasis therefore never applied at all. `isDisjoint(with:)` is the
            // "none of these are set" question that was intended here.
            let emphasisBits: Registers.PPUMask = [.emphasizeRed, .emphasizeGreen, .emphasizeBlue]
            
            guard !registers.mask.isDisjoint(with: emphasisBits) else { return color }
            
            return emphasizedColor(color)
        }
        
        /// The cold half of `applyColorEmphasis`, deliberately kept out of line.
        @inline(never)
        private func emphasizedColor(_ color: UInt32) -> UInt32 {
            let emphasizeRed = registers.mask.contains(.emphasizeRed)
            let emphasizeGreen = registers.mask.contains(.emphasizeGreen)
            let emphasizeBlue = registers.mask.contains(.emphasizeBlue)
            
            // Each emphasis bit attenuates the two channels it does *not* emphasize,
            // so a channel dims whenever some other channel is being emphasized.
            // Setting two or more bits therefore dims every channel, which is why
            // all-three-set darkens the picture rather than leaving it untouched.
            //
            // Real hardware attenuates by roughly 15-20%; 0.8 is kept from the
            // original implementation.
            func attenuate(_ value: UInt32, _ shouldAttenuate: Bool) -> UInt32 {
                shouldAttenuate ? UInt32(Float(value) * 0.8) : value
            }
            
            let r = attenuate((color >> 16) & 0xFF, emphasizeGreen || emphasizeBlue)
            let g = attenuate((color >> 8) & 0xFF, emphasizeRed || emphasizeBlue)
            let b = attenuate(color & 0xFF, emphasizeRed || emphasizeGreen)
            
            return (r << 16) | (g << 8) | b
        }
        
        /// The 2C02 master palette, indexed by the 6-bit value stored in palette
        /// RAM. Exposed so a renderer that uploads palette indices to the GPU can
        /// do the lookup itself rather than consuming pre-resolved RGB.
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
    // MARK: - Public API Functions
    
    public func setFrameCallback(_ callback: @escaping (Result<Frame, Error>) -> Void) {
        frameCallback = callback
    }
}
