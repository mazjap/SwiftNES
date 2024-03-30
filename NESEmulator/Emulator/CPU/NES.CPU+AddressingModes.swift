extension NES.CPU {
    /// Uses the 8-bit operand itself as the value for the operation (doesn't fetch from a provided address)
    /// - Parameter addr: The 16-bit address containing the immediate value.
    /// - Returns: The immediate value fetched from the specified address.
    func getImmediate(addr: UInt16) -> UInt16 {
        UInt16(memory.read(from: addr))
    }
    
    /// Fetches the value from an 8-bit address on the zero page (bytes 0 - 256)
    /// - Parameter addr: The 16-bit address to fetch the value from.
    /// - Returns: The value fetched from the specified zero page address.
    func getZeropage(addr: UInt16) -> UInt16 {
        UInt16(memory.read(from: addr % 256))
    }

    /// Same as `Zeropage`, but using x as an offset (addr + x) % 256
    /// - Parameters:
    ///   - addr: The 16-bit base address on the zero page to which the X register offset will be added.
    ///   - x: The 8-bit value in the X register to be added as an offset to the base address.
    /// - Returns: The value fetched from the calculated address.
    func getZeropageXIndex(addr: UInt16, x: UInt8) -> UInt16 {
        let effectiveAddr = addr &+ UInt16(x)
        return getZeropage(addr: effectiveAddr)
    }

    /// Same as `Zeropage`, but using y as an offset (addr + y) % 256
    /// - Parameters:
    ///   - addr: The 16-bit base address on the zero page to which the Y register offset will be added.
    ///   - y: The 8-bit value in the Y register to be added as an offset to the base address.
    /// - Returns: The value fetched from the calculated address.
    func getZeropageYIndex(addr: UInt16, y: UInt8) -> UInt16 {
        let effectiveAddr = addr &+ UInt16(y)
        return getZeropage(addr: effectiveAddr)
    }
    
    /// Gets two subsequent bytes from `(addr + x) % 256` and `(addr + x + 1) % 256`, uses that value as another address, and returns the value from that created address
    /// - Parameters:
    ///   - addr: The 16-bit base address to which the X register offset will be added.
    ///   - x: The 8-bit value in the X register to be added as an offset to the base address.
    /// - Returns: The value fetched from the calculated address.
    func getIndirectXIndex(addr: UInt16, x: UInt8) -> UInt16 {
        let lowByteAddr = (addr &+ UInt16(x)) % 256
        let highByteAddr = (lowByteAddr &+ 1) % 256
        
        return UInt16(memory.read(from: lowByteAddr)) + UInt16((memory.read(from: highByteAddr))) << 8
    }
    
    /// Gets the low byte from `addr`, the high byte from `(addr + 1) % 256`, and adds `y` to create an effective address, then returns the value from that address
    /// - Parameters:
    ///   - addr: The 16-bit base address from which the indirect address will be fetched.
    ///   - y: The 8-bit value in the Y register to be added to the fetched indirect address.
    /// - Returns: The value fetched from the calculated address.
    func getIndirectYIndex(addr: UInt16, y: UInt8) -> UInt16 {
        let lowAddr = UInt16(memory.read(from: addr))
        let highAddr = UInt16(memory.read(from: (addr &+ 1) % 256)) << 8
        let effectiveAddr = lowAddr &+ highAddr &+ UInt16(y)
        
        return UInt16(memory.read(from: effectiveAddr))
    }
    
    /// Fetches the value from a 16-bit absolute address.
    /// - Parameter addr: The 16-bit address to fetch the value from.
    /// - Returns: The value fetched from the specified address.
    func getAbsolute(addr: UInt16) -> UInt16 {
        return UInt16(memory.read(from: addr))
    }
    
    /// Fetches the value from a 16-bit absolute address with an offset provided by the X register.
    /// - Parameters:
    ///   - addr: The 16-bit base address to which the X register offset will be added.
    ///   - x: The 8-bit value in the X register to be added as an offset to the base address.
    /// - Returns: The value fetched from the calculated address.
    func getAbsoluteXIndex(addr: UInt16, x: UInt8) -> UInt16 {
        let effectiveAddr = addr &+ UInt16(x)
        return getAbsolute(addr: effectiveAddr)
    }
    
    /// Fetches the value from a 16-bit absolute address with an offset provided by the Y register.
    /// - Parameters:
    ///   - addr: The 16-bit base address to which the Y register offset will be added.
    ///   - y: The 8-bit value in the Y register to be added as an offset to the base address.
    /// - Returns: The value fetched from the calculated address.
    func getAbsoluteYIndex(addr: UInt16, y: UInt8) -> UInt16 {
        let effectiveAddr = addr &+ UInt16(y)
        return getAbsolute(addr: effectiveAddr)
    }
}
