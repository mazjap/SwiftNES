# SwiftNES

A Nintendo Entertainment System (NES) emulator core written in Swift. This package provides the core emulation functionality for the SwiftNES Frontend. The goal of this project is to deepen understanding of system architecture, assembly language, and the inner workings of the NES by accurately replicating its functionality.

## Features

### Currently implemented

- Complete MOS 6502 CPU emulation with:
  - All official opcodes
  - Cycle-accurate timing
  - Memory management unit (MMU)
  - Full test suite
- Initial cartridge support with Mapper 0

### Under Development

The emulator is still in development, and several key components are not yet implemented:

- [ ] Picture Processing Unit (PPU)
  - [ ] Core rendering pipeline
  - [ ] Background and sprite rendering
  - [ ] Palette management

- [ ] Audio Processing Unit (APU)
  - [ ] Waveform generation
  - [ ] Audio mixing
  - [ ] Channel emulation

- [ ] Extended cartridge support
  - [ ] Multiple mapper implementations
  - [ ] Battery-backed save support

- [ ] Debug tooling
  - [ ] Assembler
  - [ ] Dissasembler
  - [ ] Memory visualizer & manipulator

- Highly unstable instructions as described by [masswerk](https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes) (which I currently do not plan to implement)
  
## Technical Implementation Details

### CPU/PPU Synchronization

This emulator uses instruction-level synchronization rather than cycle-accurate emulation. While the original NES hardware runs all components (CPU, PPU, APU) off a single master clock, this emulator completes an entire CPU instruction before updating other components. After each CPU instruction, the PPU and APU (once implemented) will be advanced by the corresponding number of cycles.

This will simplify the implementation and make debugging easier while maintaining sufficient accuracy. Timing-critical operations (like VBlank) occur at scanline/frame boundaries rather than individual cycles, so this approach will preserve the necessary timing relationships for video output. Sprite zero hits 

### Frame Rate

The original NES runs at 60.1 FPS, but this emulator will target 60 FPS to match modern displays. This will result in the emulator running ~0.17% slower than original hardware. This difference should be imperceptible during gameplay, and will avoid potential frame skips from trying to maintain 60.1 FPS on 60 Hz displays.

### Other Timing Considerations

- Audio timing: The APU will be updated in chunks rather than continuously
- Input polling: Controller input will be sampled at instruction boundaries rather than individual cycles
- DMA transfers: These will appear to happen instantly from the CPU's perspective rather than taking the correct number of cycles, though the cycle count will still be appropriately added to the timing

## Installation

### Requirements

- iOS 14.0+
- macOS 11.0+
- watchOS 7.0+
- visionOS 1.0+
- tvOS 14.0+
- Swift 6.0+

### Swift Package Manager

#### Add to your app

1. In Xcode, open your project and navigate to File → Swift Packages → Add Package Dependency...
2. Paste the repository URL (https://github.com/mazjap/SwiftNES.git) and click Next.
3. For Rules, select Version (Up to Next Major) and click Next.
4. Click Finish.

[More information](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)

#### Add to your package

Add SwiftNES Core as a dependency in your Package.swift file:
```swift
dependencies: [
    .package(url: "https://github.com/mazjap/SwiftNES.git", branch: "main")
]
```

Then add it to your target dependencies:
```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SwiftNES"]
    )
]
```

## Basic Usage

```swift
import SwiftNES

// Load a ROM
let romData = // ... load your ROM data ...
let cartridge = try NES.Cartridge(data: romData)

// Initialize the emulator
let nes = NES(cartridge: cartridge)

// Run the emulator
try nes.run()
```

## Project Structure

- Sources/SwiftNES/
  - Emulator/
    - CPU/ - 6502 CPU implementation
    - PPU/ - Graphics processing
  - Helpers/
  - Managers/

## Contributing

While this is primarily a personal educational project and not accepting direct contributions, feedback and suggestions are welcome through:
- Opening issues
- Suggesting improvements
- Reporting bugs

## License

This project is released under the MIT License. See the [LICENSE file](./LICENSE) for more information. Attribution, while not required, is appreciated.

## Acknowledgments

Thanks to these resources for their extensive documentation:

  1. [NESDev Wiki](https://www.nesdev.org/wiki/Nesdev_Wiki) - Comprehensive NES hardware documentation
  2. [Masswerk](https://www.masswerk.at/nowgobang/2021/6502-illegal-opcodes) - 6502 illegal opcodes
  3. [Emulator101](http://www.emulator101.com/6502-addressing-modes.html) - 6502 addressing modes
  4. [Cdot Wiki](https://wiki.cdot.senecapolytechnic.ca/wiki/6502_Addressing_Modes) - Additional addressing mode documentation

And many more
