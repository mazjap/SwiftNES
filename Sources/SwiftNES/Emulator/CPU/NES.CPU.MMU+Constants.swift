extension NES.CPU.MemoryManagementUnit {
    public enum MemoryMap {
        public static let internalRamMask: UInt16 = 0x07FF
        
        public static let ppuRegisterBase: UInt16 = 0x2000
        public static let ppuRegisterMask: UInt16 = 0x7
        
        public static func resolveRamAddress(address: UInt16) -> UInt16 {
            address & internalRamMask
        }
 
        public static func resolvePpuRegister(address: UInt16) -> UInt8 {
            UInt8((address - ppuRegisterBase) & ppuRegisterMask)
        }
    }
}
