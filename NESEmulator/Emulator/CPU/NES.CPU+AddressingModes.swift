extension NES.CPU {
    /// Returns the program counter, unmodified, but adds 1 clock cycle.
    /// - Returns: The program counter
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getImmediateAddress() -> UInt16 {
        clockCycleCount += 1
        return registers.programCounter
    }
    
    /// Fetches the 8-bit zero page address from the provided 8-bit base address, optionally applying an offset
    /// - Parameters:
    ///   - addr: The 8-bit base address from which to fetch the value
    ///   - offset: An optional 8-bit offset to add to the base address, used in indexed zero page addressing modes
    /// - Returns: The resolved zero page address after applying the offset
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getZeropageAddress(addr: UInt8, offset: UInt8? = nil) -> UInt16 {
        clockCycleCount += 2 // Base cycles for ZeroPage access
        var resolvedAddress = addr // Ensure address is within the zero page range
        
        if let offset {
            clockCycleCount += 1 // Indexed ZeroPage access requires an additional cycle
            resolvedAddress = (resolvedAddress &+ offset)
        }
        
        return UInt16(resolvedAddress)
    }
    
    /// Calculates the memory address using the Indexed Indirect addressing mode. Gets the low byte from `(addr + x) % 256`, the high byte from `(addr + x + 1) % 256`, then returns the calculated address
    /// - Parameter addr: The 8-bit base address to which the X register offset will be added
    /// - Returns: The resolved 16-bit address calculated from the low and high bytes
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getIndexedIndirectAddress(addr: UInt8) -> UInt16 {
        let baseAddr = UInt16(addr) &+ UInt16(registers.indexX)
        let lowByteAddr = UInt16(memoryManager.read(from: baseAddr & 0xFF))
        let highByteAddr = UInt16(memoryManager.read(from: (baseAddr &+ 1) & 0xFF)) << 8
        
        clockCycleCount += 5 // Base cycles for (indirect,x) access
        
        return highByteAddr | lowByteAddr
    }

    /// Calculates the memory address using the Indirect Indexed addressing mode. Gets the low byte from `addr % 256`, the high byte from `(addr + 1) % 256`, and adds `y` to create an effective address, then returns the calculated address
    /// - Parameter addr: The base address
    /// - Returns: The calculated memory address
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getIndirectIndexedAddress(addr: UInt8) -> UInt16 {
        let addr16 = UInt16(addr)
        let lowByteAddr = UInt16(memoryManager.read(from: addr16 & 0xFF))
        let highByteAddr = UInt16(memoryManager.read(from: (addr16 &+ 1) & 0xFF)) << 8
        var resolvedAddress = lowByteAddr | highByteAddr
        clockCycleCount += 4 // Base cycles for (indirect),y access
        
        if isCrossingPageBoundary(addr: resolvedAddress, offset: registers.indexY) {
            clockCycleCount += 1
        }
        
        resolvedAddress &+= UInt16(registers.indexY)
        
        return resolvedAddress
    }
    
    /// Calculates the absolute memory address by adding an optional offset to the base address
    /// - Parameters:
    ///   - lsb: The least significant byte of the address to fetch from
    ///   - msb: The most significant byte, combined with `lsb` to create the effective address
    ///   - offset: An optional offset to be added to the base address
    /// - Returns: The calculated absolute memory address
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getAbsoluteAddress(lsb: UInt8, msb: UInt8, offset: UInt8? = nil) -> UInt16 {
        clockCycleCount += 3 // Base cycles for absolute/abs,x/abs,y access
        var resolvedAddress = UInt16(lsb) | (UInt16(msb) << 8)
        
        if let offset {
            clockCycleCount += 1 // Add 1 cycle for abs,x or abs,y operations due to offset addition
            if isCrossingPageBoundary(addr: resolvedAddress, offset: offset) {
                clockCycleCount += 1
            }
            resolvedAddress &+= UInt16(offset)
        }
        
        return resolvedAddress
    }
    
    /// Calculates the target address for an indirect jump, replicating the 6502 page boundary bug
    /// - Parameters:
    ///   - lsb: The least significant byte of the pointer address
    ///   - msb: The most significant byte of the pointer address
    /// - Returns: The resolved jump target address
    /// - Note: When the pointer address is at $xxFF, the high byte is fetched from $xx00
    ///         instead of $(xx+1)00 due to a hardware bug in the 6502
    func getIndirectJumpAddress(lsb: UInt8, msb: UInt8) -> UInt16 {
        let pointerAddress = UInt16(lsb) | (UInt16(msb) << 8)
        
        // Get low byte of target address
        let targetLow = memoryManager.read(from: pointerAddress)
        
        // Calculate address for high byte, implementing the page-crossing bug
        let highByteAddr = if lsb == 0xFF {
            // Bug: When pointer is at $xxFF, high byte is fetched from $xx00
            pointerAddress & 0xFF00
        } else {
            // Normal case: High byte fetched from next address
            pointerAddress + 1
        }
        
        let targetHigh = memoryManager.read(from: highByteAddr)
        
        clockCycleCount += 5  // Indirect JMP takes 5 cycles
        
        return UInt16(targetLow) | (UInt16(targetHigh) << 8)
    }
    
    /// Calculates whether adding an offset to an address causes a page boundary crossing (oops cycle)
    fileprivate func isCrossingPageBoundary(addr: UInt16, offset: UInt8) -> Bool {
        let initialPage = addr & 0xFF00
        let offsetAddr = addr &+ UInt16(offset)
        let finalPage = offsetAddr & 0xFF00
        return initialPage != finalPage
    }
}

extension NES.CPU {
    /// Fetches the 8-bit zero page address from the provided 8-bit base address, using the X register to apply an offset
    /// - Parameters:
    ///   - addr: The 8-bit base address from which to fetch the value
    /// - Returns: The resolved zero page address after applying the offset
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getZeropageXAddress(addr: UInt8) -> UInt16 {
        getZeropageAddress(addr: addr, offset: registers.indexX)
    }
    
    /// Fetches the 8-bit zero page address from the provided 8-bit base address, using the Y register to apply an offset
    /// - Parameters:
    ///   - addr: The 8-bit base address from which to fetch the value
    /// - Returns: The resolved zero page address after applying the offset
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getZeropageYAddress(addr: UInt8) -> UInt16 {
        getZeropageAddress(addr: addr, offset: registers.indexY)
    }
    
    /// Calculates the absolute memory address, using the X register as an offset to the base address
    /// - Parameters:
    ///   - lsb: The least significant byte of the address to fetch from
    ///   - msb: The most significant byte, combined with `lsb` to create the effective address
    /// - Returns: The calculated absolute memory address
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getAbsoluteXAddress(lsb: UInt8, msb: UInt8) -> UInt16 {
        getAbsoluteAddress(lsb: lsb, msb: msb, offset: registers.indexX)
    }
    
    /// Calculates the absolute memory address, using the Y register as an offset to the base address
    /// - Parameters:
    ///   - lsb: The least significant byte of the address to fetch from
    ///   - msb: The most significant byte, combined with `lsb` to create the effective address
    /// - Returns: The calculated absolute memory address
    /// - Note: This function increments the clock cycle count based on the addressing mode used
    func getAbsoluteYAddress(lsb: UInt8, msb: UInt8) -> UInt16 {
        getAbsoluteAddress(lsb: lsb, msb: msb, offset: registers.indexY)
    }
}
