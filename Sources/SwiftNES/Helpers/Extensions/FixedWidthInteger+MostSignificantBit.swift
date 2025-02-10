import Foundation

extension FixedWidthInteger {
    static var mostSignificantBit: Self {
        return 1 << (Magnitude.bitWidth - 1)
    }
}
