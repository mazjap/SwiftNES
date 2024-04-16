import Foundation

typealias NES = NintendoEntertainmentSystem
class NintendoEntertainmentSystem {
    var cpu: CPU
    var ppu: PPU
    var apu: APU
    var memoryManager: MMU
    var input: InputHandler
    
    init(cartridge: Cartridge? = nil) {
        let memoryManager = MMU(cartridge: cartridge)
        
        self.cpu = CPU(memoryManager: memoryManager)
        self.ppu = PPU()
        self.apu = APU()
        self.memoryManager = memoryManager
        self.input = InputHandler()
        
        // TODO: - Post init steps:
        // - Initialize components and load ROM
        // - Set up memory mapping
        // - Configure input handling
    }
    
    func run() throws {
        guard memoryManager.cartridge != nil else { throw NESError.cartridge(.noCartridge) }
        
        while true {
            // Emulation loop
            let cpuCycles = cpu.executeNextInstruction()
//            ppu.step(cpuCycles)
//            apu.step(cpuCycles)
            // Handle other components as needed
        }
    }
}
