import Foundation

public typealias NES = NintendoEntertainmentSystem

public class NintendoEntertainmentSystem {
    public var cpu: CPU
    public var ppu: PPU
    public var apu: APU
    public var memoryManager: MMU
    public var input: InputHandler
    
    public init(cartridge: Cartridge? = nil) {
        let memoryManager = MMU(cartridge: cartridge)
        self.memoryManager = memoryManager
        
        self.cpu = CPU(memoryManager: memoryManager)
        self.ppu = PPU(memoryManager: memoryManager, triggerNMI: { [unowned cpu] in
            cpu.triggerNMI()
        })
        self.apu = APU()
        self.input = InputHandler()
        
        memoryManager.readPPURegister = { [unowned ppu] register in
            ppu.read(from: register)
        }
        memoryManager.writePPURegister = { [unowned ppu] value, register in
            ppu.write(value, to: register)
        }
        
        self.reset()
        
        // TODO: - Post init steps:
        // - Initialize components and load ROM
        // - Set up memory mapping
        // - Configure input handling
    }
    
    public func run() throws {
        guard memoryManager.cartridge != nil else { throw NESError.cartridge(.noCartridge) }
        
        while true {
            // Emulation loop
            let cpuCycles = cpu.executeNextInstruction()
            
            // PPU steps 3 times per cpu step
            for _ in 0..<cpuCycles * 3 {
                ppu.step(cpuCycles)
            }
            
            for _ in 0..<cpuCycles {
                apu.step(cpuCycles)
            }
            
            // Handle other components as needed
        }
    }
    
    public func reset() {
        cpu.reset()
        ppu.reset()
        apu.reset()
        
        // TODO: - Possibly reset memoryManager & input
    }
}
