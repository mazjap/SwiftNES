import Testing
import NESEmulator

@Suite("CPU Stack Operations")
class StackTests {
    @Test("Stack pointer decrements when pushed")
    func testStackPointerDecrementOnPush() async throws {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        let initialSP = cpu.registers.stackPointer
        
        cpu.push(0x42)
        
        #expect(cpu.registers.stackPointer == initialSP &- 1,
               "Stack pointer should decrement after push")
    }
    
    @Test("Stack pointer increments when popped")
    func testStackPointerIncrementOnPop() async throws {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        
        cpu.push(0x42)
        let beforePop = cpu.registers.stackPointer
        _ = cpu.pop()
        
        #expect(cpu.registers.stackPointer == beforePop &+ 1,
               "Stack pointer should increment after pop")
    }
    
    // Not technically a stack overflow, just a stack wrap (but stackOverflow makes me feel like a haxor 😎)
    @Test("Stack handles full page wrap correctly")
    func testStackOverflow() async throws {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        
        // Fill the entire stack page
        cpu.registers.stackPointer = 0xFF
        for i: UInt8 in 0...0xFF {
            cpu.push(i)
        }
        
        #expect(cpu.registers.stackPointer == 0xFF,
               "Stack pointer should wrap to 0xFF after 256 pushes")
        
        // Verify values were stored correctly
        for i: UInt8 in (0...0xFF).reversed() {
            let value = cpu.pop()
            #expect(value == i, "Stack values should be preserved across wrap")
        }
        
        #expect(cpu.registers.stackPointer == 0xFF,
               "Stack pointer should return to 0xFF after emptying")
    }
    
    @Test("Stack peek reads correct value")
    func testStackPeek() async throws {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        
        cpu.push(0x42)
        let peekValue = cpu.peek()
        let popValue = cpu.pop()
        
        #expect(peekValue == 0x42, "Peek should read correct value")
        #expect(peekValue == popValue, "Peek should read same value as subsequent pop")
    }
    
    @Test("Stack operations verify range")
    func testStackAddressing() async throws {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        
        // Push a value and verify it's in stack page
        cpu.push(0x42)
        
        let stackAddr = 0x100 + UInt16(cpu.registers.stackPointer + 1)
        let stackValue = mmu.read(from: stackAddr)
        
        #expect(stackAddr >= 0x100 && stackAddr <= 0x1FF,
               "Stack operations should stay within stack page")
        #expect(stackValue == 0x42, "Stack value should be stored at correct address")
    }
}
