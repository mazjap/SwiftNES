extension NES.CPU {
    public typealias MMU = MemoryManagementUnit
    
    /// Represents the CPU's address space within the NES.
    /// Handles memory mapping and access to various components including:
    /// - Internal RAM (0x0000-0x1FFF, mirrored every 0x800 bytes)
    /// - PPU registers (0x2000-0x3FFF, mirrored every 8 bytes)
    /// - APU and I/O registers (0x4000-0x4017)
    /// - Cartridge space (0x4020-0xFFFF)
    public class MemoryManagementUnit: Memory {
        var internalRAM: NES.RandomAccessMemory
        var cartridge: NES.Cartridge?
        var readPPURegister: ((_ register: UInt8) -> UInt8)?
        var writePPURegister: ((_ value: UInt8, _ register: UInt8) -> Void)?
        var handleOAMDMA: ((UInt8) -> Void)?
        
        public init(
            internalRAM: NES.RandomAccessMemory = .init(),
            cartridge: NES.Cartridge? = nil,
            readPPURegister: ((_ register: UInt8) -> UInt8)? = nil,
            writePPURegister: ((_ value: UInt8, _ register: UInt8) -> Void)? = nil,
            handleOAMDMA: ((UInt8) -> Void)? = nil
        ) {
            self.internalRAM = internalRAM
            self.cartridge = cartridge
            self.readPPURegister = readPPURegister
            self.writePPURegister = writePPURegister
            self.handleOAMDMA = handleOAMDMA
        }
        
        /// Accesses memory at the specified address and allows modification of the value.
        /// - Parameters:
        ///   - address: The memory address to access
        ///   - modify: A closure that receives a mutable reference to the value at the address
        /// - Note: This method handles memory mirroring and component-specific access rules
        @_disfavoredOverload
        func access(at address: UInt16, modify: (inout UInt8) -> Void) {
            var defaultReturn: UInt8 = 0
            
            switch address {
            case 0x0000...0x1FFF:
                // Internal RAM and its mirrors
                internalRAM.access(at: MemoryMap.resolveRamAddress(address: address), modify: modify)
            case 0x2000...0x3FFF:
                guard let readPPURegister, let writePPURegister else {
                    emuLogger.error("Received access/modify request to PPU register, but no PPU register access handlers were provided")
                    return
                }
                
                let resolvedAddress = MemoryMap.resolvePpuRegister(address: address)
                
                var currentValue = readPPURegister(resolvedAddress)
                modify(&currentValue)
                writePPURegister(currentValue, resolvedAddress)
            case 0x4000...0x4017:
                // TODO: - Retreive from APU and IO registers
                modify(&defaultReturn)
            case 0x4018...0x401F:
                // APU and IO functionality that is normally disabled
                modify(&defaultReturn)
            case 0x4020...0xFFFF:
                // Handled by Cartridges mapper
                guard let cartridge else {
                    emuLogger.error("Read request failed: Cartridge is nil for address: \(address) (\(String(address, radix: 16)))")
                    modify(&defaultReturn)
                    return
                }
                
                var copy = cartridge.read(from: address)
                modify(&copy)
                cartridge.write(copy, to: address)
            default:
                // Switch's cases are exhaustive, but swift doesn't check for types that aren't enum, tuple, or the specific Bool struct (https://forums.swift.org/t/switch-on-int-with-exhaustive-cases-still-needs-default/49548)
                                                                                          //        _______
                                                                                          //       /       \
                fatalError("Switch wasn't exhaustive for \(address) (\(String(address, radix: 16))) 👁️👄👁️")
            }                                                                             //      |\       /|
        }                                                                                 //        ‾T‾‾‾T‾
                                                                                          //         ⅃   L
                                                                                          //  I am an ascii art god
        public func read(from address: UInt16) -> UInt8 {
            var value: UInt8 = 0
            access(at: address) { value = $0 }
            
            return value
        }
        
        public func write(_ value: UInt8, to address: UInt16) {
            if address == 0x4014 {
                handleOAMDMA?(value)
            } else {
                access(at: address) { $0 = value }
            }
        }
    }
}
