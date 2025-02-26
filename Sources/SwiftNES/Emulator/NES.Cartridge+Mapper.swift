public enum NametableMirroring {
    case horizontal
    case vertical
    case singleScreenLower
    case singleScreenUpper
    case fourScreen
}

public protocol Mapper: Memory {
    var prgROM: [UInt8] { get }
    var chrROM: [UInt8] { get }
    
    var prgStart: UInt16 { get }
    var prgEnd: UInt16 { get }
    
    var mirroringMode: NametableMirroring { get }
}

extension Mapper {
    var prgSize: UInt16 {
        prgEnd - prgStart + 1
    }
}

extension NES.Cartridge {
    typealias NROM = Mapper0
    typealias MMC1 = Mapper1
}

extension NES.Cartridge {
    class Mapper0: Mapper {
        let prgROM: [UInt8]
        let chrROM: [UInt8]
        
        let prgStart: UInt16 = 0x8000
        let prgEnd: UInt16 = 0xFFFF
        
        let mirroringMode: NametableMirroring
        
        init(programMemory: [UInt8], characterMemory: [UInt8], mirroringMode: NametableMirroring = .horizontal) {
            self.prgROM = programMemory
            self.chrROM = characterMemory
            self.mirroringMode = mirroringMode
        }
        
        func read(from address: UInt16) -> UInt8 {
            switch address {
            case prgStart...prgEnd:
                // PRG ROM - used by the CPU
                // NES assumes 32KB of PRG ROM, but some cartridges only have 16KB
                // If there's less than 32KB, the data gets mirrored to fill all 32KB (0x8000-0xBFFF) == (0xC000-0xFFFF)
                let normalizedAddress = Int(address - 0x8000)
                let mirrorAddress = normalizedAddress % prgROM.count
                return prgROM[mirrorAddress]
            case 0x0000...0x1FFF:
                // CHR ROM - used by the PPU
                return chrROM[Int(address) % chrROM.count]
            default:
                // Addresses outside of the defined ranges are typically not used.
                // Returning 0 for simplicity, but error handling could be added.
                print("Mapper0 read from unsupported address: \(address)")
                return 0
            }
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            // Mapper0 doesn't support writing to any RAM
        }
    }
}

extension NES.Cartridge {
    class Mapper1: Mapper {
        let prgROM: [UInt8]
        let chrROM: [UInt8]
        
        let prgStart: UInt16 = 0x8000
        let prgEnd: UInt16 = 0xFFFF
        
        var mirroringMode: NametableMirroring
        
        // Registers
        private var shiftRegister: UInt8 = 0x10
        private var controlRegister: UInt8 = 0x0C
        private var chrBank0: UInt8 = 0
        private var chrBank1: UInt8 = 0
        private var prgBank: UInt8 = 0
        
        // Optional PRG RAM (8KB)
        private var prgRAM: [UInt8]
        private var prgRAMEnabled: Bool = true
        
        // Calculated values for faster lookup
        private var prgBankMode: UInt8 { (controlRegister >> 2) & 0x03 }
        private var chrBankMode: UInt8 { (controlRegister >> 4) & 0x01 }
        
        init(programMemory: [UInt8], characterMemory: [UInt8], mirroringMode: NametableMirroring = .horizontal) {
            self.prgROM = programMemory
            self.chrROM = characterMemory.isEmpty ? [UInt8](repeating: 0, count: 8192) : characterMemory // Default 8KB CHR RAM if empty
            self.mirroringMode = mirroringMode
            self.prgRAM = [UInt8](repeating: 0, count: 8192) // 8KB PRG RAM
            
            // Reset to power-up state
            self.shiftRegister = 0x10
            self.controlRegister = 0x0C // Fixed 32KB mode, CHR ROM mode
        }
        
        func read(from address: UInt16) -> UInt8 {
            switch address {
            case 0x0000...0x1FFF: // CHR ROM/RAM
                return readCHR(from: address)
                
            case 0x6000...0x7FFF: // PRG RAM
                if prgRAMEnabled {
                    return prgRAM[Int(address - 0x6000)]
                }
                return 0
                
            case 0x8000...0xFFFF: // PRG ROM
                return readPRG(from: address)
                
            default:
                return 0
            }
        }
        
        private func readCHR(from address: UInt16) -> UInt8 {
            // 4KB CHR bank mode (chrBankMode == 0) or 8KB CHR bank mode (chrBankMode == 1)
            if chrBankMode == 0 {
                // 4KB bank mode: two separate switchable banks
                if address < 0x1000 {
                    // First 4KB bank (controlled by chrBank0)
                    let bankOffset = Int(chrBank0) * 4096
                    let chrAddress = bankOffset + Int(address)
                    return chrROM[chrAddress % chrROM.count]
                } else {
                    // Second 4KB bank (controlled by chrBank1)
                    let bankOffset = Int(chrBank1) * 4096
                    let chrAddress = bankOffset + Int(address - 0x1000)
                    return chrROM[chrAddress % chrROM.count]
                }
            } else {
                // 8KB bank mode: single bank controlled by chrBank0 (ignoring lowest bit)
                let bankOffset = Int(chrBank0 & 0xFE) * 4096
                let chrAddress = bankOffset + Int(address)
                return chrROM[chrAddress % chrROM.count]
            }
        }
        
        private func readPRG(from address: UInt16) -> UInt8 {
            // Calculate which 16KB bank to use based on prgBankMode and address
            let bankNumber: Int
            let bankOffset: Int
            
            switch prgBankMode {
            case 0, 1: // 32KB mode
                // Uses lowest bit of PRG bank register, shifts left to multiply by 2
                bankNumber = Int(prgBank & 0x0E) >> 1
                bankOffset = bankNumber * 32768 + Int(address - 0x8000)
                
            case 2: // Fixed first bank / switchable second bank
                if address < 0xC000 {
                    // Fixed first bank
                    bankOffset = Int(address - 0x8000)
                } else {
                    // Switchable second bank
                    bankNumber = Int(prgBank)
                    bankOffset = bankNumber * 16384 + Int(address - 0xC000)
                }
                
            case 3: // Switchable first bank / fixed last bank
                if address < 0xC000 {
                    // Switchable first bank
                    bankNumber = Int(prgBank)
                    bankOffset = bankNumber * 16384 + Int(address - 0x8000)
                } else {
                    // Fixed last bank
                    let lastBankNumber = (prgROM.count / 16384) - 1
                    bankOffset = lastBankNumber * 16384 + Int(address - 0xC000)
                }
                
            default:
                bankOffset = Int(address - 0x8000)
            }
            
            // Ensure we stay within bounds of PRG ROM
            return prgROM[bankOffset % prgROM.count]
        }
        
        func write(_ value: UInt8, to address: UInt16) {
            switch address {
            case 0x0000...0x1FFF:
                // Writing to CHR ROM/RAM
                if chrROM.count <= 8192 {
                    // Treat as CHR RAM if size is 8KB or less
                    // (Note: Would need to make chrROM mutable for this to work)
                    // In a real implementation, you'd need a separate mutable array for CHR RAM
                }
                
            case 0x6000...0x7FFF:
                // PRG RAM
                if prgRAMEnabled {
                    prgRAM[Int(address - 0x6000)] = value
                }
                
            case 0x8000...0xFFFF:
                // MMC1 register writes
                if (value & 0x80) != 0 {
                    // Reset
                    shiftRegister = 0x10
                    controlRegister |= 0x0C
                    return
                }
                
                // Serial shift register
                let complete = (shiftRegister & 1) != 0
                shiftRegister = ((shiftRegister >> 1) | ((value & 1) << 4))
                
                if complete {
                    let registerValue = shiftRegister
                    shiftRegister = 0x10
                    updateRegister(value: registerValue, address: address)
                }
            default:
                break // Should never occur
            }
        }
        
        private func updateRegister(value: UInt8, address: UInt16) {
            let region = (address >> 13) & 0x03
            
            switch region {
            case 0: // Control ($8000-$9FFF)
                controlRegister = value
                
                // Update mirroring mode based on bits 0-1 of control register
                switch value & 0x03 {
                case 0: mirroringMode = .singleScreenLower
                case 1: mirroringMode = .singleScreenUpper
                case 2: mirroringMode = .vertical
                case 3: mirroringMode = .horizontal
                default: break
                }
                
            case 1: // CHR Bank 0 ($A000-$BFFF)
                chrBank0 = value & 0x1F // 5-bit value
                
            case 2: // CHR Bank 1 ($C000-$DFFF)
                chrBank1 = value & 0x1F // 5-bit value
                
            case 3: // PRG Bank ($E000-$FFFF)
                prgBank = value & 0x0F // 4-bit value
                prgRAMEnabled = (value & 0x10) == 0 // PRG RAM enabled when bit 4 is clear
                
            default:
                break
            }
        }
    }
}

// TODO: - Create mappers 2-10
