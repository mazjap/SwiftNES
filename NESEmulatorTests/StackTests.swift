import Testing
@testable import NESEmulator

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
    @Test("Stack handles forward page wrap correctly")
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
    
    @Test("Stack handles backward page wrap correctly")
    func testStackUnderflow() {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        
        // Start with empty stack
        cpu.registers.stackPointer = 0xFF
        
        // Pop from empty stack should wrap to 0x00
        let _ = cpu.pop()
        #expect(cpu.registers.stackPointer == 0x00, "Stack pointer should wrap from 0xFF to 0x00")
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
    
    @Test("Stack operations stay within stack page")
    func testStackPageBoundaries() {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        
        // Write to memory just before and after stack page
        mmu.write(0xAA, to: 0x00FF) // Just before stack
        mmu.write(0xBB, to: 0x0200) // Just after stack
        
        // Perform stack operations
        
        cpu.push(0x42)
        
        // Verify surrounding memory wasn't affected
        #expect(mmu.read(from: 0x00FF) == 0xAA, "Memory before stack should be unchanged")
        #expect(mmu.read(from: 0x0200) == 0xBB, "Memory after stack should be unchanged")
    }
    
    @Test("Stack maintains integrity during mixed operations")
    func testStackMixedOperations() {
        let mmu = NES.MMU()
        let cpu = NES.CPU(memoryManager: mmu)
        
        // Mix of pushes and pops
        cpu.push(0x01)
        cpu.push(0x02)
        let value1 = cpu.pop()
        cpu.push(0x03)
        let value2 = cpu.pop()
        let value3 = cpu.pop()
        
        #expect(value1 == 0x02, "Stack should maintain LIFO order")
        #expect(value2 == 0x03, "Stack should handle interleaved operations")
        #expect(value3 == 0x01, "Stack should preserve earlier values")
    }
}
