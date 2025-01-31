extension NES {
    public class PPU {
        struct Registers {
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
            var oamData: UInt8
            
            /// Scroll Register ($2005) write-only x2
            /// Controls fine scrolling of the background
            var scroll: UInt16
            
            /// PPU Address Register ($2006) write-only x2
            /// Specifies the address in VRAM to access via PPUDATA
            var addr: UInt16
            
            /// PPU Data Register ($2007) read/write
            /// Read/write data from/to VRAM at the address specified by PPUADDR
            var data: UInt8
            
            /// OAM DMA Register ($4014) write-only
            /// Writing to this register initiates a DMA transfer from CPU memory to OAM
            var oamDma: UInt8
        }
        
        func step(_ cycleCount: UInt8) {
            // TODO: - Implement me
        }
    }
}
