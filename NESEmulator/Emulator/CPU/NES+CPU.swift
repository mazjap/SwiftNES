extension NES {
    class CPU {
        let memory: Memory
        var registers: Registers
        var clockCycleCount: UInt8
        
        init(memory: Memory, registers: Registers = Registers(), clockCycleCount: UInt8 = 0) {
            self.memory = memory
            self.registers = registers
            self.clockCycleCount = clockCycleCount
        }
        
        func executeNextInstruction() -> UInt8 {
            clockCycleCount = 0
            
            let opcode = getOpcode()
            
//            resolveAndCall(opcode)
            
            return clockCycleCount
        }
    }
}
