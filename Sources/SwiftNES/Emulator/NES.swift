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
    public var input: InputHandler
    public private(set) var cartridge: Cartridge?
    
    public init(cartridge: Cartridge? = nil) {
        self.cartridge = cartridge
        let memoryManager = CPU.MMU(cartridge: cartridge)
        
        self.cpu = CPU(memoryManager: memoryManager)
        self.ppu = PPU(cartridge: cartridge, triggerNMI: { [unowned cpu] in
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
    
    func run(options: NESRunOption? = nil) throws -> NESRunResult {
        guard cartridge != nil else { throw NESError.cartridge(.noCartridge) }
        
        var totalCycles: UInt64 = 0
        var totalInstructions: UInt64 = 0

        while true {
            // Execute one CPU instruction
            let cpuCycles = cpu.executeNextInstruction()
            
            totalCycles += UInt64(cpuCycles)
            totalInstructions += 1
            
            // PPU steps 3 times per CPU cycle
            for _ in 0..<cpuCycles * 3 {
                ppu.step()
            }
            
            // APU steps once per CPU cycle
            for _ in 0..<cpuCycles {
                apu.step()
            }
            
            // Early exit check. The counts carried back are the totals actually
            // reached, which can overshoot the limit by up to one instruction —
            // the loop only tests on instruction boundaries.
            switch options {
            case let .maxRunCount(.cycles(maxCycles)):
                if totalCycles >= maxCycles {
                    return .limitReached(.cycles(totalCycles))
                }
            case let .maxRunCount(.instructions(maxInstructions)):
                if totalInstructions >= maxInstructions {
                    return .limitReached(.instructions(totalInstructions))
                }
            case let .specificInstruction(instructionSet):
                if instructionSet.contains(cpu.lastInstruction) {
                    return .instructionOccurred(cpu.lastInstruction)
                }
            case .none:
                break
            }
        }
    }
    
    public func run(options: NESRunOption? = nil, frameCallback: @escaping (Result<PPU.Frame, Error>) -> Void) throws -> NESRunResult {
        ppu.setFrameCallback(frameCallback)
        return try run(options: options)
    }
    
    public enum FrameOrFinish: Sendable {
        case frame(PPU.Frame)
        case finish(NESRunResult)
    }
    
    /// Runs the emulator on a dedicated thread, delivering each completed frame
    /// through the returned stream.
    ///
    /// - Note: `AsyncThrowingStream`'s build closure runs synchronously, so the
    ///   emulation loop *cannot* be started from inside it — doing so blocks the
    ///   caller for as long as the emulator runs (forever, with no run options).
    ///   The loop gets its own thread instead, and the returned stream is usable
    ///   immediately.
    ///
    /// - Important: The emulator is handed off to that thread for the lifetime of
    ///   the stream. Mutating this `NES` from anywhere else while the stream is
    ///   alive is a data race.
    ///
    /// - Parameter framesPerSecond: Real-time pacing target. Unthrottled, the
    ///   emulator produces frames as fast as the host can manage (~170fps on
    ///   current hardware), which is both wrong for playback and faster than any
    ///   consumer can render. Pass `0` to disable pacing and run flat out.
    public func runStream(
        options: NESRunOption? = nil,
        framesPerSecond: Double = 60
    ) throws -> AsyncThrowingStream<FrameOrFinish, Error> {
        // Ownership moves to the emulation thread; see the note above.
        nonisolated(unsafe) let emulator = self
        let frameInterval = framesPerSecond > 0 ? 1 / framesPerSecond : 0

        // `bufferingNewest(1)` keeps the consumer honest: if rendering a frame
        // takes longer than producing one, the stale frames are dropped instead
        // of piling up in an unbounded queue that the UI can never drain.
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let thread = Thread {
                var nextFrameDeadline = Date.timeIntervalSinceReferenceDate

                do {
                    let result = try emulator.run(options: options) { frameResult in
                        switch frameResult {
                        case let .success(frame):
                            continuation.yield(.frame(frame))

                            guard frameInterval > 0 else { return }

                            nextFrameDeadline += frameInterval
                            let now = Date.timeIntervalSinceReferenceDate

                            if now < nextFrameDeadline {
                                Thread.sleep(forTimeInterval: nextFrameDeadline - now)
                            } else {
                                // Ran long. Resynchronize to now rather than
                                // accumulating debt and then sprinting to repay it.
                                nextFrameDeadline = now
                            }
                        case let .failure(error):
                            continuation.finish(throwing: error)
                        }
                    }

                    continuation.yield(.finish(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            thread.name = "com.mazjap.SwiftNES.emulation"
            thread.start()
        }
    }
    
    public func reset() {
        cpu.reset()
        ppu.reset(cartridge: cartridge)
        apu.reset()
        
        // TODO: - Possibly reset memoryManager & input
    }
    
    public func load(cartridge: Cartridge?) {
        self.cartridge = cartridge
        cpu.memoryManager.cartridge = cartridge
        ppu.memoryManager.cartridge = cartridge

        // The reset vector lives in the cartridge, so the CPU has to be reset
        // *after* the swap. Without this the program counter keeps whatever the
        // previous cartridge (or no cartridge at all) resolved to.
        reset()
    }
}
