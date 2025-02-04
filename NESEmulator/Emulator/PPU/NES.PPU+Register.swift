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
        var oamData: UInt8 {
            get { memory.readOAM(from: oamAddr) }
            set { memory.writeOAM(newValue, to: oamAddr) }
        }
        /// Scroll Register ($2005) write-only x2
        /// Controls fine scrolling of the background
        var scroll: UInt16
        
        /// PPU Address Register ($2006) write-only x2
        /// Specifies the address in VRAM to access via PPUDATA
        var addr: UInt16
        
        /// PPU Data Register ($2007) read/write
        /// Read/write data from/to VRAM at the address specified by PPUADDR
        var data: UInt8 {
            get { memory.read(from: addr) }
            set { memory.write(newValue, to: addr) }
        }
        
        /// OAM DMA Register ($4014) write-only
        /// Writing to this register initiates a DMA transfer from CPU memory to OAM
        var oamDma: UInt8
        
        private var writeToggle = false  // Toggles between high/low byte
        private var lastDataBusValue: UInt8 = 0 // Used when accessing write-only registers
        
        init(memory: Memory, ctrl: PPUCtrl, mask: PPUMask, status: PPUStatus, oamAddr: UInt8, scroll: UInt16, addr: UInt16, oamDma: UInt8, writeToggle: Bool = false) {
            self.memory = memory
            self.ctrl = ctrl
            self.mask = mask
            self.status = status
            self.oamAddr = oamAddr
            self.scroll = scroll
            self.addr = addr
            self.oamDma = oamDma
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
    
    mutating func read(from register: UInt8) -> UInt8 {
        let value = switch register {
        // Write-only registers return last data bus value
        case 0x00, 0x01, 0x03, 0x05, 0x06: lastDataBusValue
        case 0x02: status.readAndClear()
        case 0x04: oamData
        case 0x07: data // TODO: - Implement PPUData buffer
        default: fatalError("Read request to non-existent PPU Register: \(String(format: "%02x", register))")
        }
        
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
                scrollY = value
            } else {
                scrollX = value
            }
            
            writeToggle.toggle()
        case 0x06:
            if writeToggle {
                addrHigh = value
            } else {
                addrLow = value
            }
            
            writeToggle.toggle()
        case 0x07: data = value // TODO: - Implement PPUData buffer
        default: fatalError("Read request to non-existent PPU Register: \(String(format: "%02x", register))")
        }
    }
}
