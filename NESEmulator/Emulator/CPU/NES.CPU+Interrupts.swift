extension NES.CPU {
    
    // MARK: - Interrupt Triggers
    
    public func triggerNMI() {
        nmiPending = true
    }
    
    public func triggerIRQ() {
        irqPending = true
    }
    
    // MARK: - Interrupt Implementations
    
    internal func handleNMI() {
        // Push PC and status (similar to IRQ)
        push(UInt8((registers.programCounter >> 8) & 0xFF))
        push(UInt8(registers.programCounter & 0xFF))
        push(registers.status.rawValue & ~Registers.Status.break.rawValue)
        
        // Set interrupt disable flag
        registers.status.insert(.interrupt)
        
        // Load NMI vector
        let low = memoryManager.read(from: 0xFFFA)
        let high = memoryManager.read(from: 0xFFFB)
        registers.programCounter = UInt16(high) << 8 | UInt16(low)
        
        clockCycleCount += 7
        nmiPending = false
    }
    
    internal func handleIRQ() {
        guard !registers.status.contains(.interrupt) else {
            return
        }
        
        // Push PC and status
        push(UInt8((registers.programCounter >> 8) & 0xFF))
        push(UInt8(registers.programCounter & 0xFF))
        push(registers.status.rawValue & ~Registers.Status.break.rawValue)
        
        // Set interrupt disable flag
        registers.status.insert(.interrupt)
        
        // Load IRQ vector
        let low = memoryManager.read(from: 0xFFFE)
        let high = memoryManager.read(from: 0xFFFF)
        registers.programCounter = UInt16(high) << 8 | UInt16(low)
        
        clockCycleCount += 7
        
        irqPending = false
    }
}
