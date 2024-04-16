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
            guard address < memory.count else {
                fatalError("Memory out of bounds")
            }
            return memory[Int(address)]
        }

        func write(_ value: UInt8, to address: UInt16) {
            guard address < memory.count else {
                fatalError("Memory out of bounds")
            }
            memory[Int(address)] = value
        }
    }
    
    func loadProgram(data: [Data]) throws {
        
    }
    
    func loadProgram(at filePath: String) throws {
        
    }
}

extension NES.CPU {
    func push(_ value: UInt8) {
        registers.stackPointer &-= 1
        memoryManager.write(value, to: 0x100 + UInt16(registers.stackPointer))
    }
    
    func pop() -> UInt8 {
        defer { registers.stackPointer &+= 1 }
        return memoryManager.read(from: 0x100 + UInt16(registers.stackPointer))
    }
    
    func peek() -> UInt8 {
        memoryManager.read(from: 0x100 + UInt16(registers.stackPointer))
    }
}
