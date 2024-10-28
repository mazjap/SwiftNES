extension NES.CPU {
    func getOpcode() -> UInt8 {
        let opValue = getNextByte()
        
        // Could be any UInt8 value
        return opValue
    }
}
