extension NES {
    class CPU {
        let memory: Memory
        var registers: Registers
        
        init(memory: Memory) {
            self.memory = memory
            self.registers = Registers()
        }
    }
}
