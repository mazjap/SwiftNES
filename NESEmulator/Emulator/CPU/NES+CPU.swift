extension NES {
    class CPU {
        let memoryManager: MMU
        var registers: Registers
        var clockCycleCount: UInt8
        
        init(memoryManager: MMU, registers: Registers = Registers(), clockCycleCount: UInt8 = 0) {
            self.memoryManager = memoryManager
            self.registers = registers
            self.clockCycleCount = clockCycleCount
        }
        
        func getNextByte() -> UInt8 {
            let opValue = memoryManager.read(from: registers.programCounter)
            incrementPc()
            return opValue
        }
        
        func fetchAddress(for opcode: UInt8) -> UInt16? {
            if immediateOps.contains(opcode) {
                let value = getImmediateAddress()
                registers.programCounter += 1
                
                return value
            } else if zeropageOps.contains(opcode) {
                return getZeropageAddress(addr: getNextByte())
            } else if zeropageXOps.contains(opcode) {
                return getZeropageXAddress(addr: getNextByte())
            } else if zeropageYOps.contains(opcode) {
                return getZeropageYAddress(addr: getNextByte())
            } else if absoluteOps.contains(opcode) {
                return getAbsoluteAddress(lsb: getNextByte(), msb: getNextByte())
            } else if absoluteXOps.contains(opcode) {
                return getAbsoluteXAddress(lsb: getNextByte(), msb: getNextByte())
            } else if absoluteYOps.contains(opcode) {
                return getAbsoluteYAddress(lsb: getNextByte(), msb: getNextByte())
            } else if indirectIndexedOps.contains(opcode) {
                return getIndirectIndexedAddress(addr: getNextByte())
            } else if indexedIndirectOps.contains(opcode) {
                return getIndexedIndirectAddress(addr: getNextByte())
            } else if indirectOps.contains(opcode) {
                return getIndirectJumpAddress(lsb: getNextByte(), msb: getNextByte())
            } else {
                return nil
            }
        }
        
        /// Executes the next instruction in the program sequence.
        /// - Returns: The number of CPU cycles consumed by the instruction execution.
        /// - Note: This includes the cycle for fetching the opcode and any additional cycles for addressing modes.
        @discardableResult // discardable for testing convenience
        func executeNextInstruction() -> UInt8 {
            clockCycleCount = 0
            
            let opcode = getOpcode()
            
            switch codeToCallingMode[opcode] {
            case let .noParam(fun):
                if !impliedOps.contains(opcode) {
                    print("ERROR: - An opcode with no parameters was called that isn't an implied opcode! \(opcode)")
                }
                
                // TODO: - handle accumulator-only cases here, if that's the route I decide to go down. See `OpcodeCallingMode` TODO message
                
                fun()
            case let .mutatingValue(fun):
                if accumulatorOps.contains(opcode) {
                    fun(&registers.accumulator, true)
                } else if let addr = fetchAddress(for: opcode) {
                    memoryManager.access(at: addr) { mutableValue in
                        fun(&mutableValue, false)
                    }
                } else {
                    fatalError("Ran into unhandled case!\n\tOpcode \(opcode)")
                }
            case let .mutating(fun):
                if accumulatorOps.contains(opcode) {
                    fun(&registers.accumulator)
                } else if let addr = fetchAddress(for: opcode) {
                    memoryManager.access(at: addr) { mutableValue in
                        fun(&mutableValue)
                    }
                } else {
                    fatalError("Ran into unhandled case!\n\tOpcode \(opcode)")
                }
            case let .nonMutating(fun):
                if let addr = fetchAddress(for: opcode) {
                    fun(memoryManager.read(from: addr))
                } else {
                    fatalError("Ran into unhandled case!\n\tOpcode \(opcode)")
                }
            case let .nonMutatingAddress(fun):
                if let addr = fetchAddress(for: opcode) {
                    fun(addr)
                } else {
                    fatalError("Ran into unhandled case!\n\tOpcode \(opcode)")
                }
            case .none:
                fatalError("No opcode calling mode was found for opcode \(opcode)")
            }
            
            return clockCycleCount
        }
        
        // TODO: - Consider other implementations...
        // Not really sure how I feel about `OpcodeCallingMode` and the `codeToCallingMode`
        // dictionary as solutions to mapping opcodes to instructions and managing unsupported
        // addressing modes, but it's better than a humongous switch statement 🤷
        
        enum OpcodeCallingMode {
            // For memory modifications
            case mutating((inout UInt8) -> Void)
            // Bool indicates accumulator mode. Used for opcodes that support both accumulator-mode and address-mode (like asl)
            // TODO: - Separate concerns - asl (and friends) should be two distinct functions. One for accumulator, and one for memory addresses. Add separate OpcodeCallingMode enum case for accumulator-only functions or default to noParam
            case mutatingValue((inout UInt8, Bool) -> Void)
            // For operations that read but don't modify
            case nonMutating((UInt8) -> Void)
            // For implied operations
            case noParam(() -> Void)
            // For operations that work with addresses
            case nonMutatingAddress((UInt16) -> Void)
        }
        
        let immediateOps: Set<UInt8> = [
            0x09, 0x0B, 0x29, 0x2B, 0x49, 0x4B, 0x69, 0x6B,
            0x80, 0x82, 0x89, 0x8B, 0xA0, 0xA2, 0xA9, 0xAB,
            0xC0, 0xC2, 0xC9, 0xCB, 0xE0, 0xE2, 0xE9, 0xEB
        ]
        let impliedOps: Set<UInt8> = [
            0x00, 0x02, 0x08, 0x12, 0x18, 0x1A, 0x22, 0x28,
            0x32, 0x38, 0x3A, 0x40, 0x42, 0x48, 0x52, 0x58,
            0x5A, 0x60, 0x62, 0x68, 0x72, 0x78, 0x7A, 0x88,
            0x8A, 0x92, 0x98, 0x9A, 0xA8, 0xAA, 0xB2, 0xB8,
            0xBA, 0xC8, 0xCA, 0xD2, 0xD8, 0xDA, 0xE8, 0xEA,
            0xF2, 0xF8, 0xFA
        ]
        let accumulatorOps: Set<UInt8> = [
            0x0A, 0x2A, 0x4A, 0x6A
        ]
        let indexedIndirectOps: Set<UInt8> = [
            0x01, 0x03, 0x21, 0x23, 0x41, 0x43, 0x61, 0x63, 
            0x81, 0x83, 0xA1, 0xA3, 0xC1, 0xC3, 0xE1, 0xE3
        ]
        let indirectIndexedOps: Set<UInt8> = [
            0x11, 0x13, 0x31, 0x33, 0x51, 0x53, 0x71, 0x73,
            0x91, 0x93, 0xB1, 0xB3, 0xD1, 0xD3, 0xF1, 0xF3
        ]
        let zeropageOps: Set<UInt8> = [
            0x04, 0x05, 0x06, 0x07, 0x24, 0x25, 0x26, 0x27,
            0x44, 0x45, 0x46, 0x47, 0x64, 0x65, 0x66, 0x67,
            0x84, 0x85, 0x86, 0x87, 0xA4, 0xA5, 0xA6, 0xA7,
            0xC4, 0xC5, 0xC6, 0xC7, 0xE4, 0xE5, 0xE6, 0xE7
        ]
        let zeropageXOps: Set<UInt8> = [
            0x14, 0x15, 0x16, 0x17, 0x34, 0x35, 0x36, 0x37,
            0x54, 0x55, 0x56, 0x57, 0x74, 0x75, 0x76, 0x77,
            0x94, 0x95, 0xB5, 0xB6, 0xB7, 0xD4, 0xD5, 0xD6,
            0xD7, 0xF4, 0xF5, 0xF6, 0xF7
        ]
        let zeropageYOps: Set<UInt8> = [
            0x96, 0x97, 0xB6, 0xB7
        ]
        let absoluteOps: Set<UInt8> = [
            0x0C, 0x0D, 0x0E, 0x0F, 0x20, 0x2C, 0x2D, 0x2E,
            0x2F, 0x4C, 0x4D, 0x4E, 0x4F, 0x6D, 0x6E, 0x6F,
            0x8C, 0x8D, 0x8E, 0x8F, 0xAC, 0xAD, 0xAE, 0xAF,
            0xCC, 0xCD, 0xCE, 0xCF, 0xEC, 0xED, 0xEE, 0xEF
        ]
        let absoluteXOps: Set<UInt8> = [
            0x1C, 0x1D, 0x1E, 0x1F, 0x3C, 0x3D, 0x3E, 0x3F,
            0x5C, 0x5D, 0x5E, 0x5F, 0x7C, 0x7D, 0x7E, 0x7F,
            0x9C, 0x9D, 0xBC, 0xBD, 0xDC, 0xDD, 0xDE, 0xDF,
            0xFC, 0xFD, 0xFE, 0xFF
        ]
        let absoluteYOps: Set<UInt8> = [
            0x19, 0x1B, 0x39, 0x3B, 0x59, 0x5B, 0x79, 0x7B,
            0x99, 0x9B, 0x9E, 0x9F, 0xB9, 0xBB, 0xBE, 0xBF,
            0xD9, 0xDB, 0xF9, 0xFB
        ]
        let relativeOps: Set<UInt8> = [
            0x10, 0x30, 0x50, 0x70, 0x90, 0xB0, 0xD0, 0xF0
        ]
        let indirectOps: Set<UInt8> = [0x6C]
        
        lazy var codeToCallingMode: [UInt8 : OpcodeCallingMode] = {[
            0x00 : .noParam(brk), 0x01 : .nonMutating(ora), 0x02 : .noParam(nop),
            0x03 : .mutating(slo), 0x04 : .noParam(nop), 0x05 : .nonMutating(ora),
            0x06 : .mutatingValue(asl), 0x07 : .mutating(slo), 0x08 : .noParam(php),
            0x09 : .nonMutating(ora), 0x0A : .mutatingValue(asl), 0x0B : .nonMutating(anc),
            0x0C : .noParam(nop), 0x0D : .nonMutating(ora), 0x0E : .mutatingValue(asl),
            0x0F : .mutating(slo), 0x10 : .nonMutating(bpl), 0x11 : .nonMutating(ora),
            0x12 : .noParam(stp), 0x13 : .mutating(slo), 0x14 : .noParam(nop),
            0x15 : .nonMutating(ora), 0x16 : .mutatingValue(asl), 0x17 : .mutating(slo),
            0x18 : .noParam(clc), 0x19 : .nonMutating(ora), 0x1A : .noParam(nop),
            0x1B : .mutating(slo), 0x1C : .noParam(nop), 0x1D : .nonMutating(ora),
            0x1E : .mutatingValue(asl), 0x1F : .mutating(slo), 0x20 : .nonMutatingAddress(jsr),
            0x21 : .nonMutating(and), 0x22 : .noParam(stp), 0x23 : .mutating(rla),
            0x24 : .nonMutating(bit), 0x25 : .nonMutating(and), 0x26 : .mutatingValue(rol),
            0x27 : .mutating(rla), 0x28 : .noParam(plp), 0x29 : .nonMutating(and),
            0x2A : .mutatingValue(rol), 0x2B : .nonMutating(anc), 0x2C : .nonMutating(bit),
            0x2D : .nonMutating(and), 0x2E : .mutatingValue(rol), 0x2F : .mutating(rla),
            0x30 : .nonMutating(bmi), 0x31 : .nonMutating(and), 0x32 : .noParam(stp),
            0x33 : .mutating(rla), 0x34 : .noParam(nop), 0x35 : .nonMutating(and),
            0x36 : .mutatingValue(rol), 0x37 : .mutating(rla), 0x38 : .noParam(sec),
            0x39 : .nonMutating(and), 0x3A : .noParam(nop), 0x3B : .mutating(rla),
            0x3C : .noParam(nop), 0x3D : .nonMutating(and), 0x3E : .mutatingValue(rol),
            0x3F : .mutating(rla), 0x40 : .noParam(rti), 0x41 : .nonMutating(eor),
            0x42 : .noParam(stp), 0x43 : .mutating(sre), 0x44 : .noParam(nop),
            0x45 : .nonMutating(eor), 0x46 : .mutatingValue(lsr), 0x47 : .mutating(sre),
            0x48 : .noParam(pha), 0x49 : .nonMutating(eor), 0x4A : .mutatingValue(lsr),
            0x4B : .nonMutating(alr), 0x4C : .nonMutatingAddress(jmp), 0x4D : .nonMutating(eor),
            0x4E : .mutatingValue(lsr), 0x4F : .mutating(sre), 0x50 : .nonMutating(bvc),
            0x51 : .nonMutating(eor), 0x52 : .noParam(stp), 0x53 : .mutating(sre),
            0x54 : .noParam(nop), 0x55 : .nonMutating(eor), 0x56 : .mutatingValue(lsr),
            0x57 : .mutating(sre), 0x58 : .noParam(cli), 0x59 : .nonMutating(eor),
            0x5A : .noParam(nop), 0x5B : .mutating(sre), 0x5C : .noParam(nop),
            0x5D : .nonMutating(eor), 0x5E : .mutatingValue(lsr), 0x5F : .mutating(sre),
            0x60 : .noParam(rts), 0x61 : .nonMutating(adc), 0x62 : .noParam(stp),
            0x63 : .mutating(rra), 0x64 : .noParam(nop), 0x65 : .nonMutating(adc),
            0x66 : .mutatingValue(ror), 0x67 : .mutating(rra), 0x68 : .noParam(pla),
            0x69 : .nonMutating(adc), 0x6A : .mutatingValue(ror), 0x6B : .mutating(arr),
            0x6C : .nonMutatingAddress(jmp), 0x6D : .nonMutating(adc), 0x6E : .mutatingValue(ror),
            0x6F : .mutating(rra), 0x70 : .nonMutating(bvs), 0x71 : .nonMutating(adc),
            0x72 : .noParam(stp), 0x73 : .mutating(rra), 0x74 : .noParam(nop),
            0x75 : .nonMutating(adc), 0x76 : .mutatingValue(ror), 0x77 : .mutating(rra),
            0x78 : .noParam(sei), 0x79 : .nonMutating(adc), 0x7A : .noParam(nop),
            0x7B : .mutating(rra), 0x7C : .noParam(nop), 0x7D : .nonMutating(adc),
            0x7E : .mutatingValue(ror), 0x7F : .mutating(rra), 0x80 : .noParam(nop),
            0x81 : .nonMutatingAddress(sta), 0x82 : .noParam(nop), 0x83 : .nonMutatingAddress(sax),
            0x84 : .nonMutatingAddress(sty), 0x85 : .nonMutatingAddress(sta), 0x86 : .nonMutatingAddress(stx),
            0x87 : .nonMutatingAddress(sax), 0x88 : .noParam(dey), 0x89 : .noParam(nop),
            0x8A : .noParam(txa), 0x8B : .noParam(xaa), 0x8C : .nonMutatingAddress(sty),
            0x8D : .nonMutatingAddress(sta), 0x8E : .nonMutatingAddress(stx), 0x8F : .nonMutatingAddress(sax),
            0x90 : .nonMutating(bcc), 0x91 : .nonMutatingAddress(sta), 0x92 : .noParam(stp),
            0x93 : .noParam(ahx), 0x94 : .nonMutatingAddress(sty), 0x95 : .nonMutatingAddress(sta),
            0x96 : .nonMutatingAddress(stx), 0x97 : .nonMutatingAddress(sax), 0x98 : .noParam(tya),
            0x99 : .nonMutatingAddress(sta), 0x9A : .noParam(txs), 0x9B : .noParam(tas),
            0x9C : .noParam(shy), 0x9D : .nonMutatingAddress(sta), 0x9E : .noParam(shx),
            0x9F : .noParam(ahx), 0xA0 : .nonMutating(ldy), 0xA1 : .nonMutating(lda),
            0xA2 : .nonMutating(ldx), 0xA3 : .nonMutating(lax), 0xA4 : .nonMutating(ldy),
            0xA5 : .nonMutating(lda), 0xA6 : .nonMutating(ldx), 0xA7 : .nonMutating(lax),
            0xA8 : .noParam(tay), 0xA9 : .nonMutating(lda), 0xAA : .noParam(tax),
            0xAB : .nonMutating(lax), 0xAC : .nonMutating(ldy), 0xAD : .nonMutating(lda),
            0xAE : .nonMutating(ldx), 0xAF : .nonMutating(lax), 0xB0 : .nonMutating(bcs),
            0xB1 : .nonMutating(lda), 0xB2 : .noParam(stp), 0xB3 : .nonMutating(lax),
            0xB4 : .nonMutating(ldy), 0xB5 : .nonMutating(lda), 0xB6 : .nonMutating(ldx),
            0xB7 : .nonMutating(lax), 0xB8 : .noParam(clv), 0xB9 : .nonMutating(lda),
            0xBA : .noParam(tsx), 0xBB : .nonMutating(las), 0xBC : .nonMutating(ldy),
            0xBD : .nonMutating(lda), 0xBE : .nonMutating(ldx), 0xBF : .nonMutating(lax),
            0xC0 : .nonMutating(cpy), 0xC1 : .nonMutating(cmp), 0xC2 : .noParam(nop),
            0xC3 : .mutating(dcp), 0xC4 : .nonMutating(cpy), 0xC5 : .nonMutating(cmp),
            0xC6 : .mutating(dec), 0xC7 : .mutating(dcp), 0xC8 : .noParam(iny),
            0xC9 : .nonMutating(cmp), 0xCA : .noParam(dex), 0xCB : .nonMutating(axs),
            0xCC : .nonMutating(cpy), 0xCD : .nonMutating(cmp), 0xCE : .mutating(dec),
            0xCF : .mutating(dcp), 0xD0 : .nonMutating(bne), 0xD1 : .nonMutating(cmp),
            0xD2 : .noParam(stp), 0xD3 : .mutating(dcp), 0xD4 : .noParam(nop),
            0xD5 : .nonMutating(cmp), 0xD6 : .mutating(dec), 0xD7 : .mutating(dcp),
            0xD8 : .noParam(cld), 0xD9 : .nonMutating(cmp), 0xDA : .noParam(nop),
            0xDB : .mutating(dcp), 0xDC : .noParam(nop), 0xDD : .nonMutating(cmp),
            0xDE : .mutating(dec), 0xDF : .mutating(dcp), 0xE0 : .nonMutating(cpx),
            0xE1 : .nonMutating(sbc), 0xE2 : .noParam(nop), 0xE3 : .mutating(isc),
            0xE4 : .nonMutating(cpx), 0xE5 : .nonMutating(sbc), 0xE6 : .mutating(inc),
            0xE7 : .mutating(isc), 0xE8 : .noParam(inx), 0xE9 : .nonMutating(sbc),
            0xEA : .noParam(nop), 0xEB : .nonMutating(sbc), 0xEC : .nonMutating(cpx),
            0xED : .nonMutating(sbc), 0xEE : .mutating(inc), 0xEF : .mutating(isc),
            0xF0 : .nonMutating(beq), 0xF1 : .nonMutating(sbc), 0xF2 : .noParam(stp),
            0xF3 : .mutating(isc), 0xF4 : .noParam(nop), 0xF5 : .nonMutating(sbc),
            0xF6 : .mutating(inc), 0xF7 : .mutating(isc), 0xF8 : .noParam(sed),
            0xF9 : .nonMutating(sbc), 0xFA : .noParam(nop), 0xFB : .mutating(isc),
            0xFC : .noParam(nop), 0xFD : .nonMutating(sbc), 0xFE : .mutating(inc),
            0xFF : .mutating(isc),
        ]}()
    }
}
