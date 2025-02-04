extension NES {
    public class PPU {
        private var registers: Registers
        private var cycle: Int = 0
        private var scanline: Int = 0
        private var frame: Int = 0
        private var isOddFrame: Bool = false
        private var memory: Memory
        
        init(memoryManager: MMU) {
            let memory = Memory(cartridge: memoryManager.cartridge)
            
            self.memory = memory
            
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
            // TODO: - Implement me
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
