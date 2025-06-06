import Foundation

public typealias NES = NintendoEntertainmentSystem

public enum NESMaxRunCount: Sendable {
    case cycles(UInt64)
    case instructions(UInt64)
}

public enum NESRunResult: Sendable {
    case limitReached(NESMaxRunCount)
    case instructionOccurred(UInt8)
}

public enum NESRunOption: Sendable {
    case maxRunCount(NESMaxRunCount)
    case specificInstruction(Set<UInt8>)
}

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
        
        memoryManager.handleOAMDMA = { [unowned cpu] page in
            cpu.performOAMDMA(page: page)
        }
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
    
    public func run(options: NESRunOption? = nil) throws -> NESRunResult {
        guard memoryManager.cartridge != nil else { throw NESError.cartridge(.noCartridge) }
        
        var totalCycles: UInt64 = 0
        var totalInstructions = 0
        
        while true {
            let prevNmiPending = ppu.nmiPending
            
            // Execute one CPU instruction
            let cpuCycles = cpu.executeNextInstruction()
            
            totalCycles += UInt64(cpuCycles)
            totalInstructions += 1
            
            // PPU steps 3 times per CPU cycle
            for _ in 0..<cpuCycles * 3 {
                ppu.step()
                
                // Check if NMI was triggered during this PPU cycle
                if !prevNmiPending && ppu.nmiPending && cpu.registers.status.readFlag(.interrupt) == false {
                    cpu.triggerNMI()
                }
            }
            
            // APU steps once per CPU cycle
            for _ in 0..<cpuCycles {
                apu.step()
            }
            
            // Early exit check
            switch options {
            case let .maxRunCount(.cycles(maxCycles)):
                return .limitReached(.cycles(maxCycles))
            case let .maxRunCount(.instructions(maxInstructions)):
                return .limitReached(.instructions(maxInstructions))
            case let .specificInstruction(instructionSet):
                if instructionSet.contains(cpu.lastInstruction) {
                    return .instructionOccurred(cpu.lastInstruction)
                }
            case .none:
                break
            }
        }
    }
    
    public func reset() {
        cpu.reset()
        ppu.reset(cartridge: memoryManager.cartridge)
        apu.reset()
        
        // TODO: - Possibly reset memoryManager & input
    }
}
