extension NES {
    public class PPU {
        var registers: Registers
        var cycle: Int = 0 // 0-340 pixels per scanline
        var scanline: Int = 0 // 0-261 scanlines per frame
        var frame: Int = 0
        var isOddFrame: Bool = false // Used for skipped cycle on odd frames
        var memory: Memory
        var setNMI: () -> Void
        
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
        }
        
        func step(_ cycleCount: UInt8) {
            if scanline == -1 && cycle == 1 {
                // Clear VBlank, sprite 0, overflow flags
                registers.status.rawValue = 0
            }
            
            if scanline >= 0 && scanline < 240 {
                // Handle visible scanlines
            } else if scanline == 241 && cycle == 1 {
                // Set VBlank flag and trigger NMI if enabled
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
