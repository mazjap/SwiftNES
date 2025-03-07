extension NES.PPU {
    struct Registers {
        private let memory: Memory
        
        /// Control Register ($2000) write-only
        /// Controls basic PPU operations and configures PPU memory access patterns
        var ctrl: PPUCtrl
        
        /// Mask Register ($2001) write-only
        /// Controls the rendering of sprites and backgrounds
        var mask: PPUMask
        
        /// Status Register ($2002) read-only
        /// Contains information about the PPU's current state
        var status: PPUStatus
        
        /// OAM Address Register ($2003) write-only
        /// Specifies the address in OAM to access via OAMDATA
        var oamAddr: UInt8
        
        /// OAM Data Register ($2004) read/write
        /// Read/write data from/to OAM at the address specified by OAMADDR
        /// - Note: Each write to `oamData` automatically increments `oamAddr` as a side effect
        var oamData: UInt8 {
            get { memory.readOAM(from: oamAddr) }
            set {
                memory.writeOAM(newValue, to: oamAddr)
                oamAddr &+= 1
            }
        }
        /// Scroll Register ($2005) write-only x2
        /// Controls fine scrolling of the background
        var scroll: UInt16
        
        /// PPU Address Register ($2006) write-only x2
        /// Specifies the address in VRAM to access via PPUDATA
        var addr: UInt16
        
        /// PPU Data Register ($2007) read/write
        /// Read/write data from/to VRAM at the address specified by PPUADDR
        /// Reading from non-palette memory returns the contents of an internal buffer,
        /// which is then filled with the newly read value.
        /// Reading from palette memory returns the value immediately and fills the
        /// buffer with the corresponding nametable data.
        var data: UInt8 {
            mutating get {
                let memoryValue = memory.read(from: addr)
                
                // Increment before any potential read buffering
                incrementDataAddress()
                
                if addr < 0x3F00 { // Not palette data - return last buffered value, store new value in buffer
                    let bufferedValue = ppuDataReadBuffer
                    ppuDataReadBuffer = memoryValue
                    return bufferedValue
                } else { // Palette data - return new value, but also store in buffer
                    // Mirror palette addresses 3F00-3FFF to 2F00-2FFF for the buffer
                    ppuDataReadBuffer = memory.read(from: 0x2000 | (addr & 0x0FFF))
                    return memoryValue
                }
            }
            set {
                memory.write(newValue, to: addr)
                incrementDataAddress()
            }
        }
        
        private var lastDataBusValue: UInt8 = 0 // Used when accessing write-only registers
        private var ppuDataReadBuffer: UInt8 = 0 // Last pulled value from memory
        var writeToggle = false  // Toggles between high/low byte
        var tempVramAddress: UInt16 = 0 // Temporary VRAM address register
        var currentVramAddress: UInt16 = 0 // Current VRAM address register
        var fineXScroll: UInt8 = 0 // Fine X scroll (3 bits)
        
        init(memory: Memory, ctrl: PPUCtrl, mask: PPUMask, status: PPUStatus, oamAddr: UInt8, scroll: UInt16, addr: UInt16, writeToggle: Bool = false) {
            self.memory = memory
            self.ctrl = ctrl
            self.mask = mask
            self.status = status
            self.oamAddr = oamAddr
            self.scroll = scroll
            self.addr = addr
            self.writeToggle = writeToggle
        }
    }
}

// MARK: - Convenience

extension NES.PPU.Registers {
    private var scrollX: UInt8 {
        get {
            UInt8(scroll & 0xFF)
        }
        set {
            scroll = (scroll & 0xFF00) | UInt16(newValue)
        }
    }
    
    private var scrollY: UInt8 {
        get {
            UInt8(scroll >> 8)
        }
        set {
            scroll = (scroll & 0xFF) | (UInt16(newValue) << 8)
        }
    }
    
    private var addrHigh: UInt8 {
        get {
            UInt8(addr >> 8)
        }
        set {
            addr = (addr & 0xFF) | (UInt16(newValue) << 8)
        }
    }
    
    private var addrLow: UInt8 {
        get {
            UInt8(addr & 0xFF)
        }
        set {
            addr = (addr & 0xFF00) | UInt16(newValue)
        }
    }
    
    private mutating func incrementDataAddress() {
        addr = (addr + ctrl.vramAddressIncrement) & 0x3FFF
    }
    
    mutating func read(from register: UInt8) -> UInt8 {
        let value = {
            switch register {
                // Write-only registers return last data bus value
            case 0x00, 0x01, 0x03, 0x05, 0x06:
                emuLogger.notice("Attempted read from write-only PPU status register")
                return lastDataBusValue
            case 0x02:
                writeToggle = false
                return status.readAndClear()
            case 0x04:
                return oamData
            case 0x07:
                return data
            default:
                fatalError("Read request to non-existent PPU Register: \(String(format: "%02x", register))")
            }
        }()
        
        lastDataBusValue = value
        return value
    }
    
    mutating func write(_ value: UInt8, to register: UInt8) {
        lastDataBusValue = value
        
        switch register {
        case 0x00: ctrl.rawValue = value
        case 0x01: mask.rawValue = value
        case 0x02:
            // Status register is read-only
            emuLogger.warning("Attempted write to read-only PPU status register")
            return
        case 0x03: oamAddr = value
        case 0x04: oamData = value
        case 0x05:
            if writeToggle {
                // Second write (Y scroll)
                tempVramAddress = (tempVramAddress & 0x8FFF) | (UInt16(value & 0x7) << 12) // Fine Y scroll (3 bits)
                tempVramAddress = (tempVramAddress & 0xFC1F) | (UInt16(value & 0xF8) << 2) // Coarse Y scroll (5 bits)
            } else {
                // First write (X scroll)
                fineXScroll = value & 0x7 // Fine X scroll (3 bits)
                tempVramAddress = (tempVramAddress & 0xFFE0) | (UInt16(value) >> 3) // Coarse X scroll (5 bits)
            }
            
            writeToggle.toggle()
        case 0x06:
            if writeToggle {
                // First write (high byte)
                tempVramAddress = (tempVramAddress & 0x00FF) | (UInt16(value & 0x3F) << 8) // Set high byte, clear unused bits
            } else {
                // Second write (low byte)
                tempVramAddress = (tempVramAddress & 0xFF00) | UInt16(value)
                currentVramAddress = tempVramAddress // Copy temp to current on second write
            }
            
            writeToggle.toggle()
        case 0x07: data = value
        default: fatalError("Write request to non-existent PPU Register: \(String(format: "%02x", register))")
        }
    }
}
