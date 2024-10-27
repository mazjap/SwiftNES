extension NES.CPU {
    func getOpcode() -> UInt8 {
        let opValue = getNextByte()
        clockCycleCount += 1
        
        // Could be any UInt8 value
        return opValue
    }
}
