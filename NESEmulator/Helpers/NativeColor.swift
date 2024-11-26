import SwiftUI

#if os(macOS)
typealias NativeColor = NSColor
#else
typealias NativeColor = UIColor
#endif

extension Color {
    init(nativeColor: NativeColor) {
        #if os(macOS)
        self.init(nsColor: nativeColor)
        #else
        self.init(uiColor: nativeColor)
        #endif
    }
}
