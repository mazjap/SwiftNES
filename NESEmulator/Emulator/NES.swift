import Foundation

typealias NES = NintendoEntertainmentSystem
class NintendoEntertainmentSystem {
    var cpu: CPU
    var ppu: PPU
    var apu: APU
    var memory: Memory
    var cartridge: Cartridge
    var input: InputHandler
    
    init() {
        let memory = Memory()
        
        self.cpu = CPU(memory: memory)
        self.ppu = PPU()
        self.apu = APU()
        self.memory = memory
        self.cartridge = Cartridge()
        self.input = InputHandler()
        
        // TODO: - Post init steps:
        // - Initialize components and load ROM
        // - Set up memory mapping
        // - Configure input handling
    }
    
    func run() {
        while true {
            // Emulation loop
//            let cpuCycles = cpu.executeNextInstruction()
//            ppu.step(cpuCycles)
//            apu.step(cpuCycles)
            // Handle other components as needed
        }
    }
}
