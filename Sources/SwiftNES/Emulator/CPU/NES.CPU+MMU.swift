extension NES.CPU {
    public typealias MMU = MemoryManagementUnit
    
    /// Represents the CPU's address space within the NES.
    /// Handles memory mapping and access to various components including:
    /// - Internal RAM (0x0000-0x1FFF, mirrored every 0x800 bytes)
    /// - PPU registers (0x2000-0x3FFF, mirrored every 8 bytes)
    /// - APU and I/O registers (0x4000-0x4017)
    /// - Cartridge space (0x4020-0xFFFF)
    public class MemoryManagementUnit: Memory {
        public var internalRAM: NES.RandomAccessMemory
        public var cartridge: NES.Cartridge?
        public var readPPURegister: ((_ register: UInt8) -> UInt8)?
        public var writePPURegister: ((_ value: UInt8, _ register: UInt8) -> Void)?
        public var handleOAMDMA: ((UInt8) -> Void)?
        
        public init(
            internalRAM: NES.RandomAccessMemory = .init(),
            cartridge: NES.Cartridge? = nil,
            readPPURegister: ((_ register: UInt8) -> UInt8)? = nil,
            writePPURegister: ((_ value: UInt8, _ register: UInt8) -> Void)? = nil,
            handleOAMDMA: ((UInt8) -> Void)? = nil
        ) {
            self.internalRAM = internalRAM
            self.cartridge = cartridge
            self.writePPURegister = writePPURegister
            self.handleOAMDMA = handleOAMDMA
            
            self.readPPURegister = { register in
                guard let readPPURegister else { return 0 }
                let result = readPPURegister(register)
                
                print("While reading from PPU at register 0x\(String(register, radix: 16))")
                return result
            }
            
            self.writePPURegister = { register, value in
                guard let writePPURegister else { return }
                
                let regNames = ["PPUCTRL", "PPUMASK", "PPUSTATUS", "OAMADDR", "OAMDATA", "PPUSCROLL", "PPUADDR", "PPUDATA"]
                let regName = register < regNames.count ? regNames[Int(register)] : "UNKNOWN"
                
                print("📝 PPU Write: \(regName) = $\(String(value, radix: 16, uppercase: true))")
                
                // Special handling for palette-related writes
                if register == 0x06 { // PPUADDR
                    print("   📍 PPUADDR write - setting address pointer")
                } else if register == 0x07 { // PPUDATA
                    // This is tricky - we need to know what the current address is
                    print("   📝 PPUDATA write - writing to PPU memory")
                    print("   💡 Check if PPUADDR was recently set to $3F00-$3F1F for palette writes")
                }
            }
        }
        
        /// Accesses memory at the specified address and allows modification of the value.
        /// - Parameters:
        ///   - address: The memory address to access
        ///   - modify: A closure that receives a mutable reference to the value at the address
        /// - Note: This method handles memory mirroring and component-specific access rules
        @_disfavoredOverload
        public func access(at address: UInt16, modify: (inout UInt8) -> Void) {
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
