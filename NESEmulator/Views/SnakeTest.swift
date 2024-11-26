import SwiftUI

struct SnakeTestView: View {
    @State private var keysPressed = Set<KeyEquivalent>()
    @State private var cycle = 0
    @State private var color: Color = .clear
    let emulator = NES()
    
    var body: some View {
        Canvas { context, size in
            let squareSize = CGSize(width: size.width / 0x20, height: size.height / 0x20)

            _ = cycle
            for i in (0x0200..<0x0600) as Range<UInt16> {
                let x = (i - 0x0200) % 0x20
                let y = (i - 0x0200) / 0x20

                let squareOrigin = CGPoint(x: squareSize.width * CGFloat(x), y: squareSize.height * CGFloat(y))

                context.fill(
                    Rectangle().path(in: CGRect(origin: squareOrigin, size: squareSize)),
                    with: .color(Color(nativeColor: color(for: emulator.memoryManager.read(from: i))))
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            do {
                try await emulator.runWithCallback {
                    cycle += 1

                    emulator.memoryManager.write(UInt8.random(in: 1..<16), to: 0xfe)
                    if (keysPressed.contains(.upArrow) && keysPressed.contains(.downArrow)) ||
                        (keysPressed.contains(.leftArrow) && keysPressed.contains(.rightArrow)) {
                        // Do nothing
                    } else if keysPressed.contains(.upArrow) {
                        emulator.memoryManager.write(0x77, to: 0xff)
                    } else if keysPressed.contains(.downArrow) {
                        emulator.memoryManager.write(0x73, to: 0xff)
                    } else if keysPressed.contains(.leftArrow) {
                        emulator.memoryManager.write(0x61, to: 0xff)
                    } else if keysPressed.contains(.rightArrow) {
                        emulator.memoryManager.write(0x64, to: 0xff)
                    }
                }
            } catch {
                print(error)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .up]) { keyPress in
            switch keyPress.phase {
            case .down:
                keysPressed.insert(keyPress.key)
                return .handled
            case .up:
                keysPressed.remove(keyPress.key)
                return .handled
            default:
                return .ignored
            }
        }
    }
    
    private func color(for byte: UInt8) -> NativeColor {
        switch byte {
        case 0: .black
        case 1: .white
        case 2, 9: .gray
        case 3, 10: .red
        case 4, 11: .green
        case 5, 12: .blue
        case 6, 13: .magenta
        case 7, 14: .yellow
        default: .cyan
       }
    }
}

#Preview {
    ContentView()
}
