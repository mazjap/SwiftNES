extension NES {
    class CPU {
        let memoryManager: MMU
        var registers: Registers
        var clockCycleCount: UInt8
        
        init(memoryManager: MMU, registers: Registers = Registers(), clockCycleCount: UInt8 = 0) {
            self.memoryManager = memoryManager
            self.registers = registers
            self.clockCycleCount = clockCycleCount
        }
        
        func executeNextInstruction() -> UInt8 {
            clockCycleCount = 0
            
            do {
                let opcode = try getOpcode()
                
//                resolveAndCall(opcode)
                
                return clockCycleCount
            } catch {
                // TODO: - Proper error handling
                fatalError(error.localizedDescription + "\n" + "Please implement better error handling")
            }
        }
    }
}
