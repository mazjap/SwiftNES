import Foundation

enum NESError: Error {
    case cartridge(CartridgeError)
}

enum CartridgeError: Error {
    case noCartridge
    case invalidHeader([UInt8])
}
