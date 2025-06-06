extension NES.CPU.MemoryManagementUnit {
    enum MemoryMap {
        static let internalRamMask: UInt16 = 0x07FF
        
        static let ppuRegisterBase: UInt16 = 0x2000
        static let ppuRegisterMask: UInt16 = 0x7
        
        static func resolveRamAddress(address: UInt16) -> UInt16 {
            address & internalRamMask
        }
 
        static func resolvePpuRegister(address: UInt16) -> UInt8 {
            UInt8((address - ppuRegisterBase) & ppuRegisterMask)
        }
    }
}
