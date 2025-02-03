extension NES {
    public class PPU {
        var registers: Registers
        var vramReadBuffer: UInt8 = 0
        var isEvenFrame: Bool = false
        
        
        init() {
            self.registers = Registers(
                ctrl: .init(rawValue: 0),
                mask: .init(rawValue: 0),
                status: .init(rawValue: 0),
                oamAddr: 0,
                oamData: 0,
                scroll: 0,
                addr: 0,
                data: 0,
                oamDma: 0
            )
        }
        
        func step(_ cycleCount: UInt8) {
            // TODO: - Implement me
        }
        
        func reset() {
            // TODO: - Implement me
        }
        
        func read(from register: UInt8) -> UInt8 {
            registers.read(from: register)
        }
        
        func write(_ value: UInt8, to register: UInt8) {
            registers.write(value, to: register)
        }
    }
}
