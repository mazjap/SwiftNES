extension NES {
    class CPU {
        let memory: Memory
        var registers: Registers
        var clockCycleCount: UInt
        
        init(memory: Memory, registers: Registers = Registers(), clockCycleCount: UInt = 0) {
            self.memory = memory
            self.registers = registers
            self.clockCycleCount = clockCycleCount
        }
    }
}
