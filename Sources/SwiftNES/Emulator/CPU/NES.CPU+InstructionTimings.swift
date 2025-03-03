extension NES.CPU {
    /// Represents the timing characteristics of a 6502 CPU instruction
    struct InstructionTiming {
        /// Enum representing the stability of an instruction (particularly for illegal opcodes)
        enum Stability {
            case stable                // Normal, documented instruction
            case illegalStable         // Illegal opcode with predictable behavior
            case illegalUnstable       // Illegal opcode with relatively predictable behavior
            case illegalHighlyUnstable // Illegal opcode with very unpredictable behavior
            case fatal                 // KIL/STP/HLT opcode that jams the CPU
        }
        
        let baseCycles: UInt16
        let addPageCross: Bool  // Whether to add cycle for page boundary crossing
        let addSuccessfulBranch: Bool // Whether branching occurred
        let stability: Stability
        
        /// Whether this instruction is considered legal/documented
        var isLegal: Bool {
            stability == .stable
        }
        
        /// Whether this instruction can be reliably emulated
        var isReliable: Bool {
            switch stability {
            case .stable, .illegalStable:
                return true
            case .illegalUnstable, .illegalHighlyUnstable, .fatal:
                return false
            }
        }
        
        /// Whether this instruction might have timing variations
        var hasVariableTiming: Bool {
            addPageCross || addSuccessfulBranch
        }
        
        func cycleCount(pageCrossed: Bool, branchOccurred: Bool) -> UInt16 {
            var count = baseCycles
            
            if addPageCross && pageCrossed {
                count += 1
            }
            
            if addSuccessfulBranch && branchOccurred {
                count += 1
            }
            
            return count
        }
        
        /// Instruction's clock cycle count could be increased by one, depending on if a page boundary is crossed
        static func pageCross(_ baseCycles: UInt16) -> Self {
            Self(baseCycles: baseCycles, addPageCross: true, addSuccessfulBranch: false, stability: .stable)
        }
        
        /// Instruction's clock cycle count could be increased by two, depending on if a page boundary is crossed and/or if branch condition is successful
        static func pageBranch(_ baseCycles: UInt16) -> Self {
            Self(baseCycles: baseCycles, addPageCross: true, addSuccessfulBranch: true, stability: .stable)
        }
        
        /// Instruction's clock cycle count is static
        static func unchanged(_ baseCycles: UInt16) -> Self {
            Self(baseCycles: baseCycles, addPageCross: false, addSuccessfulBranch: false, stability: .stable)
        }
        
        /// Illegal, but stable, opcode with a static clock cycle count
        static func iUnchanged(_ baseCycles: UInt16) -> Self {
            Self(baseCycles: baseCycles, addPageCross: false, addSuccessfulBranch: false, stability: .illegalStable)
        }
        
        /// Illegal, but stable, opcode that adds one clock cycle if addressing mode crosses page boundary
        static func iPageCross(_ baseCycles: UInt16) -> Self {
            Self(baseCycles: baseCycles, addPageCross: true, addSuccessfulBranch: false, stability: .illegalStable)
        }
        
        /// Only used for kil/stp/hlt opcode
        static func gameOver() -> Self {
            Self(baseCycles: 0, addPageCross: false, addSuccessfulBranch: false, stability: .fatal)
        }
        
        /// Unstable opcode as dictated by https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes
        static func uUnchanged(_ baseCycles: UInt16) -> Self {
            Self(baseCycles: baseCycles, addPageCross: false, addSuccessfulBranch: false, stability: .illegalUnstable)
        }
        
        /// Highly unstable opcode as dictated by https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes
        static func huUnchanged(_ baseCycles: UInt16) -> Self {
            Self(baseCycles: baseCycles, addPageCross: false, addSuccessfulBranch: false, stability: .illegalHighlyUnstable)
        }
    }
    
    static let instructionTimings: [UInt8 : InstructionTiming] = [
        0x00 : .unchanged(7),    0x01 : .unchanged(6),    0x02 : .gameOver(),
        0x03 : .iUnchanged(8),   0x04 : .iUnchanged(3),   0x05 : .unchanged(3),
        0x06 : .unchanged(5),    0x07 : .iUnchanged(5),   0x08 : .unchanged(3),
        0x09 : .unchanged(2),    0x0A : .unchanged(2),    0x0B : .iUnchanged(2),
        0x0C : .iUnchanged(4),   0x0D : .unchanged(4),    0x0E : .unchanged(6),
        0x0F : .iUnchanged(6),   0x10 : .pageBranch(2),   0x11 : .pageCross(5),
        0x12 : .gameOver(),      0x13 : .iUnchanged(8),   0x14 : .iUnchanged(4),
        0x15 : .unchanged(4),    0x16 : .unchanged(6),    0x17 : .iUnchanged(6),
        0x18 : .unchanged(2),    0x19 : .pageCross(4),    0x1A : .iUnchanged(2),
        0x1B : .iUnchanged(7),   0x1C : .iPageCross(4),   0x1D : .pageCross(4),
        0x1E : .unchanged(7),    0x1F : .iUnchanged(7),   0x20 : .unchanged(6),
        0x21 : .unchanged(6),    0x22 : .gameOver(),      0x23 : .iUnchanged(8),
        0x24 : .unchanged(3),    0x25 : .unchanged(3),    0x26 : .unchanged(5),
        0x27 : .iUnchanged(5),   0x28 : .unchanged(4),    0x29 : .unchanged(2),
        0x2A : .unchanged(2),    0x2B : .iUnchanged(2),   0x2C : .unchanged(4),
        0x2D : .unchanged(4),    0x2E : .unchanged(6),    0x2F : .iUnchanged(6),
        0x30 : .pageBranch(2),   0x31 : .pageCross(5),    0x32 : .gameOver(),
        0x33 : .iUnchanged(8),   0x34 : .iUnchanged(4),   0x35 : .unchanged(4),
        0x36 : .unchanged(6),    0x37 : .iUnchanged(6),   0x38 : .unchanged(2),
        0x39 : .pageCross(4),    0x3A : .iUnchanged(2),   0x3B : .iUnchanged(7),
        0x3C : .iPageCross(4),   0x3D : .pageCross(4),    0x3E : .unchanged(7),
        0x3F : .iUnchanged(7),   0x40 : .unchanged(6),    0x41 : .unchanged(6),
        0x42 : .gameOver(),      0x43 : .iUnchanged(8),   0x44 : .iUnchanged(3),
        0x45 : .unchanged(3),    0x46 : .unchanged(5),    0x47 : .iUnchanged(5),
        0x48 : .unchanged(3),    0x49 : .unchanged(2),    0x4A : .unchanged(2),
        0x4B : .iUnchanged(2),   0x4C : .unchanged(3),    0x4D : .unchanged(4),
        0x4E : .unchanged(6),    0x4F : .iUnchanged(6),   0x50 : .pageBranch(2),
        0x51 : .pageCross(5),    0x52 : .gameOver(),      0x53 : .iUnchanged(8),
        0x54 : .iUnchanged(4),   0x55 : .unchanged(4),    0x56 : .unchanged(6),
        0x57 : .iUnchanged(6),   0x58 : .unchanged(2),    0x59 : .pageCross(4),
        0x5A : .iUnchanged(2),   0x5B : .iUnchanged(7),   0x5C : .iPageCross(4),
        0x5D : .pageCross(4),    0x5E : .unchanged(7),    0x5F : .iUnchanged(7),
        0x60 : .unchanged(6),    0x61 : .unchanged(6),    0x62 : .gameOver(),
        0x63 : .iUnchanged(8),   0x64 : .iUnchanged(3),   0x65 : .unchanged(3),
        0x66 : .unchanged(5),    0x67 : .iUnchanged(5),   0x68 : .unchanged(4),
        0x69 : .unchanged(2),    0x6A : .unchanged(2),    0x6B : .iUnchanged(2),
        0x6C : .unchanged(5),    0x6D : .unchanged(4),    0x6E : .unchanged(6),
        0x6F : .iUnchanged(6),   0x70 : .pageBranch(2),   0x71 : .pageCross(5),
        0x72 : .gameOver(),      0x73 : .iUnchanged(8),   0x74 : .iUnchanged(4),
        0x75 : .unchanged(4),    0x76 : .unchanged(6),    0x77 : .iUnchanged(6),
        0x78 : .unchanged(2),    0x79 : .pageCross(4),    0x7A : .iUnchanged(2),
        0x7B : .iUnchanged(7),   0x7C : .iPageCross(4),   0x7D : .pageCross(4),
        0x7E : .unchanged(7),    0x7F : .iUnchanged(7),   0x80 : .iUnchanged(2),
        0x81 : .unchanged(6),    0x82 : .iUnchanged(2),   0x83 : .iUnchanged(6),
        0x84 : .unchanged(3),    0x85 : .unchanged(3),    0x86 : .unchanged(3),
        0x87 : .iUnchanged(3),   0x88 : .unchanged(2),    0x89 : .iUnchanged(2),
        0x8A : .unchanged(2),    0x8B : .huUnchanged(2),  0x8C : .unchanged(4),
        0x8D : .unchanged(4),    0x8E : .unchanged(4),    0x8F : .iUnchanged(4),
        0x90 : .pageBranch(2),   0x91 : .unchanged(6),    0x92 : .gameOver(),
        0x93 : .uUnchanged(6),   0x94 : .unchanged(4),    0x95 : .unchanged(4),
        0x96 : .unchanged(4),    0x97 : .iUnchanged(4),   0x98 : .unchanged(2),
        0x99 : .unchanged(5),    0x9A : .unchanged(2),    0x9B : .uUnchanged(5),
        0x9C : .uUnchanged(5),   0x9D : .unchanged(5),    0x9E : .uUnchanged(5),
        0x9F : .uUnchanged(5),   0xA0 : .unchanged(2),    0xA1 : .unchanged(6),
        0xA2 : .unchanged(2),    0xA3 : .iUnchanged(6),   0xA4 : .unchanged(3),
        0xA5 : .unchanged(3),    0xA6 : .unchanged(3),    0xA7 : .iUnchanged(3),
        0xA8 : .unchanged(2),    0xA9 : .unchanged(2),    0xAA : .unchanged(2),
        0xAB : .huUnchanged(2),  0xAC : .unchanged(4),    0xAD : .unchanged(4),
        0xAE : .unchanged(4),    0xAF : .iUnchanged(4),   0xB0 : .pageBranch(2),
        0xB1 : .pageCross(5),    0xB2 : .gameOver(),      0xB3 : .iPageCross(5),
        0xB4 : .unchanged(4),    0xB5 : .unchanged(4),    0xB6 : .unchanged(4),
        0xB7 : .iUnchanged(4),   0xB8 : .unchanged(2),    0xB9 : .pageCross(4),
        0xBA : .unchanged(2),    0xBB : .iPageCross(4),   0xBC : .pageCross(4),
        0xBD : .pageCross(4),    0xBE : .pageCross(4),    0xBF : .iPageCross(4),
        0xC0 : .unchanged(2),    0xC1 : .unchanged(6),    0xC2 : .iUnchanged(2),
        0xC3 : .iUnchanged(8),   0xC4 : .unchanged(3),    0xC5 : .unchanged(3),
        0xC6 : .unchanged(5),    0xC7 : .iUnchanged(5),   0xC8 : .unchanged(2),
        0xC9 : .unchanged(2),    0xCA : .unchanged(2),    0xCB : .iUnchanged(2),
        0xCC : .unchanged(4),    0xCD : .unchanged(4),    0xCE : .unchanged(6),
        0xCF : .iUnchanged(6),   0xD0 : .pageBranch(2),   0xD1 : .pageCross(5),
        0xD2 : .gameOver(),      0xD3 : .iUnchanged(8),   0xD4 : .iUnchanged(4),
        0xD5 : .unchanged(4),    0xD6 : .unchanged(6),    0xD7 : .iUnchanged(6),
        0xD8 : .unchanged(2),    0xD9 : .pageCross(4),    0xDA : .iUnchanged(2),
        0xDB : .iUnchanged(7),   0xDC : .iPageCross(4),   0xDD : .pageCross(4),
        0xDE : .unchanged(7),    0xDF : .iUnchanged(7),   0xE0 : .unchanged(2),
        0xE1 : .unchanged(6),    0xE2 : .iUnchanged(2),   0xE3 : .iUnchanged(8),
        0xE4 : .unchanged(3),    0xE5 : .unchanged(3),    0xE6 : .unchanged(5),
        0xE7 : .iUnchanged(5),   0xE8 : .unchanged(2),    0xE9 : .unchanged(2),
        0xEA : .unchanged(2),    0xEB : .iUnchanged(2),   0xEC : .unchanged(4),
        0xED : .unchanged(4),    0xEE : .unchanged(6),    0xEF : .iUnchanged(6),
        0xF0 : .pageBranch(2),   0xF1 : .pageCross(5),    0xF2 : .gameOver(),
        0xF3 : .iUnchanged(8),   0xF4 : .iUnchanged(4),   0xF5 : .unchanged(4),
        0xF6 : .unchanged(6),    0xF7 : .iUnchanged(6),   0xF8 : .unchanged(2),
        0xF9 : .pageCross(4),    0xFA : .iUnchanged(2),   0xFB : .iUnchanged(7),
        0xFC : .iPageCross(4),   0xFD : .pageCross(4),    0xFE : .unchanged(7),
        0xFF : .iUnchanged(7)
    ]
}
