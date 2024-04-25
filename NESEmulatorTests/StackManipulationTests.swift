import XCTest
@testable import NESEmulator

final class StackManipulationTests: XCTestCase {
    var nes: NES?
    
    override func setUpWithError() throws {
        let nes = NES()
        
        nes.cpu.push(0x1F)
        nes.cpu.push(0x2F)
        nes.cpu.push(0xFF)
        
        self.nes = nes
    }
    
    func testStackPointerIsDecrementedWhenPushed() throws {
        let cpu = nes!.cpu
        
        let stackPointerBeforePush = cpu.registers.stackPointer
        
        cpu.push(0xF1)
        
        XCTAssertEqual(stackPointerBeforePush &- 1, cpu.registers.stackPointer, "Stack pointer did not decrement when performing a push")
    }
    
    func testStackPointerIsIncrementedWhenPopped() throws {
        let cpu = nes!.cpu
        
        let stackPointerBeforePop = cpu.registers.stackPointer
        
        _ = cpu.pop()
        
        XCTAssertEqual(stackPointerBeforePop &+ 1, cpu.registers.stackPointer, "Stack pointer did not increment when performing a pop")
    }
    
    func testPeek() throws {
        let cpu = nes!.cpu
        
        XCTAssertEqual(cpu.peek(), 0xFF)
    }
    
    func testPushToStack() throws {
        let cpu = nes!.cpu
        
        let valueToPush: UInt8 = 0x55
        cpu.push(valueToPush)
        
        XCTAssertEqual(cpu.peek(), valueToPush)
    }
    
    func testPopSequence() {
        let cpu = nes!.cpu
        
        XCTAssertEqual(cpu.pop(), 0xFF)
        XCTAssertEqual(cpu.pop(), 0x2F)
        XCTAssertEqual(cpu.pop(), 0x1F)
    }
    
    // Not technically a stack overflow, just a stack wrap (but stackOverflow makes me feel like a haxor 😎)
    func testStackOverflow() throws {
        let cpu = nes!.cpu
        cpu.registers.stackPointer = 0
        cpu.push(0x25)
        XCTAssertEqual(cpu.registers.stackPointer, 0xFF, "Stack pointer incorrectly wrapped")
    }
    
    func testStackUnderflow() throws {
        let cpu = nes!.cpu
        
        // Clear stack's test data inserted in setup function
        _ = cpu.pop()
        _ = cpu.pop()
        _ = cpu.pop()
        
        XCTAssertEqual(cpu.registers.stackPointer, 0xFD)
        
        _ = cpu.pop()
        _ = cpu.pop()
        _ = cpu.pop()
        
        XCTAssertEqual(cpu.registers.stackPointer, 0x00)
    }
    
    func testStackManipulation() throws {
        let cpu = nes!.cpu
        
        let preManipulationStackPointer = cpu.registers.stackPointer
        
        cpu.registers.indexX = 0x88
        cpu.txs() // Not yet implemented
        
        XCTAssertNotEqual(preManipulationStackPointer, cpu.registers.stackPointer)
        XCTAssertEqual(cpu.registers.stackPointer, cpu.registers.indexX)
    }
}
