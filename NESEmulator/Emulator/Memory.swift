protocol Memory {
    func read(from address: UInt16) -> UInt8
    func write(_ value: UInt8, to address: UInt16)
}

extension Memory {
    subscript(addr: UInt16) -> UInt8 {
        get {
            read(from: addr)
        }
        set {
            write(newValue, to: addr)
        }
    }
}
