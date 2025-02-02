protocol CPUMemoryAccess {
    func access(at address: UInt16, modify: (inout UInt8) -> Void)
    func read(from address: UInt16) -> UInt8
    func write(_ value: UInt8, to: UInt16)
}

extension NES.MMU: CPUMemoryAccess {}
