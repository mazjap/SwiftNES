extension NES.CPU {
    /// Handles immediate addressing mode by returning the current program counter as the address
    /// Example: LDA #$44 - The value $44 is read from the byte following the opcode
    /// - Returns: A tuple containing:
    ///   - address: The current program counter location
    ///   - pageBoundaryCrossed: Always false for immediate addressing
    func getImmediateAddress() -> (address: UInt16, pageBoundaryCrossed: Bool) {
        return (registers.programCounter, false)
    }
    
    /// Handles zero page addressing by interpreting the operand as an address in page zero ($0000-$00FF)
    /// Example: LDA $44 - The value is read from address $0044
    /// - Parameters:
    ///   - addr: The zero page address (0-255)
    ///   - offset: Optional index value (for zero page,X or zero page,Y addressing)
    /// - Returns: A tuple containing:
    ///   - address: The calculated zero page address (wraps within page zero)
    ///   - pageBoundaryCrossed: Always false as zero page addressing cannot cross pages
    func getZeropageAddress(addr: UInt8, offset: UInt8? = nil) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        var resolvedAddress = addr // Ensure address is within the zero page range
        
        if let offset {
            resolvedAddress = (resolvedAddress &+ offset)
        }
        
        return (UInt16(resolvedAddress), false)
    }
    
    /// Handles indexed indirect (X) addressing mode, aka (indirect,X) or (d,X)
    /// Example: LDA ($20,X) - If X contains $04, fetch address from $24/$25
    /// - Parameter addr: The zero page base address before X indexing
    /// - Returns: A tuple containing:
    ///   - address: The 16-bit address fetched from the indexed zero page location
    ///   - pageBoundaryCrossed: Always false as final address is fully computed before access
    /// - Note: Address calculation wraps within zero page. If addr+X=$FF, high byte comes from $00
    func getIndexedIndirectAddress(addr: UInt8) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        let baseAddr = UInt16(addr) &+ UInt16(registers.indexX)
        let lowByteAddr = UInt16(memoryManager.read(from: baseAddr & 0xFF))
        let highByteAddr = UInt16(memoryManager.read(from: (baseAddr &+ 1) & 0xFF)) << 8
        
        return (highByteAddr | lowByteAddr, false)
    }

    /// Handles indirect indexed (Y) addressing mode, aka (indirect),Y or (d),Y
    /// Example: LDA ($86),Y - Fetch base address from $86/$87, then add Y
    /// - Parameter addr: The zero page location containing the base address
    /// - Returns: A tuple containing:
    ///   - address: The computed address (base address + Y)
    ///   - pageBoundaryCrossed: True if Y indexing crosses a page boundary
    /// - Note: Page boundary crossing occurs if base address + Y crosses a page boundary
    func getIndirectIndexedAddress(addr: UInt8) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        let addr16 = UInt16(addr)
        let lowByteAddr = UInt16(memoryManager.read(from: addr16 & 0xFF))
        let highByteAddr = UInt16(memoryManager.read(from: (addr16 &+ 1) & 0xFF)) << 8
        var resolvedAddress = lowByteAddr | highByteAddr
        
        let pageBoundaryCrossed = isCrossingPageBoundary(addr: resolvedAddress, offset: registers.indexY)
        
        resolvedAddress &+= UInt16(registers.indexY)
        
        return (resolvedAddress, pageBoundaryCrossed)
    }
    
    /// Handles absolute addressing with optional indexing
    /// Example: LDA $1234 or LDA $1234,X
    /// - Parameters:
    ///   - lsb: Low byte of the target address
    ///   - msb: High byte of the target address
    ///   - offset: Optional index value (X or Y register)
    /// - Returns: A tuple containing:
    ///   - address: The final absolute address (with optional indexing applied)
    ///   - pageBoundaryCrossed: True if indexing causes a page boundary cross
    func getAbsoluteAddress(lsb: UInt8, msb: UInt8, offset: UInt8? = nil) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        var resolvedAddress = UInt16(lsb) | (UInt16(msb) << 8)
        var pageBoundaryCrossed = false
        
        if let offset {
            pageBoundaryCrossed = isCrossingPageBoundary(addr: resolvedAddress, offset: offset)
            
            resolvedAddress &+= UInt16(offset)
        }
        
        return (resolvedAddress, pageBoundaryCrossed)
    }
    
    /// Handles indirect addressing used by JMP instruction, implementing the 6502 page boundary bug
    /// Example: JMP ($1234) - Jump to address stored at $1234/$1235
    /// - Parameters:
    ///   - lsb: Low byte of the indirect pointer address
    ///   - msb: High byte of the indirect pointer address
    /// - Returns: A tuple containing:
    ///   - address: The address to jump to
    ///   - pageBoundaryCrossed: Always false as JMP timing is static
    /// - Note: Has hardware bug: JMP ($xxFF) reads high byte from $xx00 instead of $(xx+1)00
    func getIndirectJumpAddress(lsb: UInt8, msb: UInt8) -> (address: UInt16, pageBoundaryCrossed: Bool) {
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
        
        return (UInt16(targetLow) | (UInt16(targetHigh) << 8), false)
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
    /// Handles zero page,X addressing by adding X register to a zero page address
    /// Example: LDA $44,X - If X contains $20, reads from zero page address $64
    /// - Parameter addr: Base zero page address before X indexing
    /// - Returns: A tuple containing:
    ///   - address: The indexed zero page address (wraps within zero page)
    ///   - pageBoundaryCrossed: Always false as zero page indexing cannot cross pages
    /// - Note: Result wraps within zero page ($0000-$00FF) if addr + X > $FF
    func getZeropageXAddress(addr: UInt8) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        getZeropageAddress(addr: addr, offset: registers.indexX)
    }
    
    /// Handles zero page,Y addressing by adding Y register to a zero page address
    /// Example: LDX $44,Y - If Y contains $20, reads from zero page address $64
    /// - Parameter addr: Base zero page address before Y indexing
    /// - Returns: A tuple containing:
    ///   - address: The indexed zero page address (wraps within zero page)
    ///   - pageBoundaryCrossed: Always false as zero page indexing cannot cross pages
    /// - Note: Result wraps within zero page ($0000-$00FF) if addr + Y > $FF
    /// - Note: Only used by a few instructions (LDX, STX)
    func getZeropageYAddress(addr: UInt8) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        getZeropageAddress(addr: addr, offset: registers.indexY)
    }
    
    /// Handles absolute,X addressing by adding X register to a 16-bit address
    /// Example: LDA $1234,X - If X contains $20, reads from address $1254
    /// - Parameters:
    ///   - lsb: Low byte of base address
    ///   - msb: High byte of base address
    /// - Returns: A tuple containing:
    ///   - address: The computed absolute address after X indexing
    ///   - pageBoundaryCrossed: True if adding X crosses a page boundary
    /// - Note: Page boundary crossing occurs if (base + X) crosses a page boundary
    func getAbsoluteXAddress(lsb: UInt8, msb: UInt8) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        getAbsoluteAddress(lsb: lsb, msb: msb, offset: registers.indexX)
    }
    
    /// Handles absolute,Y addressing by adding Y register to a 16-bit address
    /// Example: LDA $1234,Y - If Y contains $20, reads from address $1254
    /// - Parameters:
    ///   - lsb: Low byte of base address
    ///   - msb: High byte of base address
    /// - Returns: A tuple containing:
    ///   - address: The computed absolute address after Y indexing
    ///   - pageBoundaryCrossed: True if adding Y crosses a page boundary
    /// - Note: Page boundary crossing occurs if (base + Y) crosses a page boundary
    func getAbsoluteYAddress(lsb: UInt8, msb: UInt8) -> (address: UInt16, pageBoundaryCrossed: Bool) {
        getAbsoluteAddress(lsb: lsb, msb: msb, offset: registers.indexY)
    }
}
