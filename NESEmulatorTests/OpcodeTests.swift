import XCTest
@testable import NESEmulator

final class OpcodeTests: XCTestCase {
    var nes: NES?
    
    override func setUpWithError() throws {
        let nes = NES()
        
        self.nes = nes
    }
}
