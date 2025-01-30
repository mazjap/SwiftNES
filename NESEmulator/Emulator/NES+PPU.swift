extension NES {
    public class PPU {
        struct Registers {
            var ctrl: PPUCtrl
            var mask: PPUMask
            var status: PPUStatus
            var oamAddr: UInt8
            var oamData: UInt8
            var scroll: UInt16
            var addr: UInt16
            var data: UInt8
            var oamDma: UInt8
        }
        
        func step(_ cycleCount: UInt8) {
            // TODO: - Implement me
        }
    }
}
