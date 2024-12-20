import Foundation

extension NES {
    class RandomAccessMemory: Memory {
        let size: UInt16
        private(set) var memory: [UInt8]
        
        init(size: UInt16 = 2048) {
            self.size = size
            self.memory = [UInt8](repeating: 0, count: Int(size))
        }
        
        func read(from address: UInt16) -> UInt8 {
            var value: UInt8 = 0
            access(at: address) { value = $0 }
            
            return value
        }
        
        func access(at address: UInt16, modify: (inout UInt8) -> Void) {
            guard address < memory.count else {
                fatalError("Memory access out of bounds")
            }
            
            modify(&memory[Int(address)])
        }

        func write(_ value: UInt8, to address: UInt16) {
            guard address < memory.count else {
                fatalError("Memory out of bounds")
            }
            memory[Int(address)] = value
        }
    }
}

extension NES.CPU {
    /// Pushes a value onto the stack.
    /// Stack pointer is automatically decremented.
    /// - Parameter value: The value to push onto the stack
    /// - Note: The stack wraps from $0100 through $01FF.
    ///   Stack pointer decrements after each push, wrapping from $00 to $FF.
    func push(_ value: UInt8) {
        let stackAddr = 0x100 + UInt16(registers.stackPointer)
        memoryManager.write(value, to: stackAddr)
        registers.stackPointer &-= 1 // Will naturally wrap from 0x00 to 0xFF
    }
    
    /// Pops a value from the stack.
    /// Stack pointer is automatically incremented.
    /// - Returns: The value popped from the stack
    /// - Note: The stack wraps from $0100 through $01FF.
    ///   Stack pointer increments after each pop, wrapping from $FF to $00.
    func pop() -> UInt8 {
        registers.stackPointer &+= 1 // Will naturally wrap from 0xFF to 0x00
        let stackAddr = 0x100 + UInt16(registers.stackPointer)
        let value = memoryManager.read(from: stackAddr)
        return value
    }
    
    /// Peeks at the top value on the stack without removing it.
    /// - Returns: The value at the current stack pointer
    /// - Note: Does not modify the stack pointer
    func peek() -> UInt8 {
        let stackAddr = 0x100 + UInt16(registers.stackPointer &+ 1)
        return memoryManager.read(from: stackAddr)
    }
}
