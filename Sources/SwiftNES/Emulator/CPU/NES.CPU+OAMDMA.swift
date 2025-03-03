extension NES.CPU {
    /// Initiates an OAM DMA transfer from CPU memory to PPU OAM memory
    /// - Parameter value: The high byte of the CPU memory address to copy from
    ///   (the address will be $xx00-$xxFF where xx is the provided value)
    /// - Note: Either 513 or 514 is added to the CPU's cycle count after this function is executed
    func performOAMDMA(page: UInt8) {
        // Base address to copy from (e.g., if page = $20, copy from $2000-$20FF)
        let baseAddress = UInt16(page) << 8
        
        // Copy 256 bytes from CPU memory to OAM
        for i in 0..<256 {
            let data = memoryManager.read(from: baseAddress + UInt16(i))
            memoryManager.writePPURegister?(data, 0x04) // Write to OAMDATA ($2004)
        }
        
        // OAM DMA takes 513 or 514 CPU cycles
        // - 1 cycle setup (might be on an odd cycle)
        // - 256 cycles for reading from CPU memory
        // - 256 cycles for writing to OAM
        // If DMA starts on an odd CPU cycle, add one extra cycle for alignment
        let isOddCycle = clockCycleCount % 2 != 0
        
        // Return the number of cycles consumed (513 or 514)
        clockCycleCount += isOddCycle ? 514 : 513
    }
}
