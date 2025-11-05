# Faust Workflow Guide

This guide will help you get started with Faust (Functional Audio Stream) programming language for audio DSP.

## Installation

Run the installation script:
```bash
chmod +x install_faust.sh
./install_faust.sh
```

This will:
- Install Homebrew (if not already installed)
- Install Faust via Homebrew
- Install Qt for GUI support
- Install Jack Audio for audio routing
- Create a workspace structure
- Generate example Faust files

## Workspace Structure

After installation, you'll have:
```
faust_projects/
├── examples/     # Your Faust DSP files go here
├── lib/          # Custom libraries
└── builds/       # Compiled outputs
```

## Quick Start

### 1. Run the example files
```bash
chmod +x run_faust.sh
./run_faust.sh faust_projects/examples/hello_faust.dsp
```

### 2. Create your own DSP file
```bash
cd faust_projects/examples
nano my_synth.dsp
```

### 3. Basic Faust syntax example
```faust
import("stdfaust.lib");

// A simple sine wave
freq = 440;
process = os.osc(freq) * 0.3;
```

## Compilation Targets

Faust can compile to many different platforms:

### macOS Audio Applications
```bash
faust2caqt file.dsp        # CoreAudio with Qt GUI (recommended for macOS)
faust2jack file.dsp        # Jack Audio
```

### Music Software Plugins
```bash
faust2max6 file.dsp        # Max/MSP external
faust2supercollider file.dsp  # SuperCollider UGen
faust2vst file.dsp         # VST plugin
faust2lv2 file.dsp         # LV2 plugin
faust2au file.dsp          # Audio Unit (macOS)
```

### Web and Mobile
```bash
faust2wasm file.dsp        # WebAssembly
faust2ios file.dsp         # iOS app
faust2android file.dsp     # Android app
```

### Embedded Systems
```bash
faust2teensy file.dsp      # Teensy board
faust2bela file.dsp        # Bela platform
```

## Useful Faust Commands

### View signal flow diagram
```bash
faust2svg file.dsp
open file-svg/process.svg
```

### Generate block diagram in PDF
```bash
faust2pdf file.dsp
open file.pdf
```

### Test without GUI
```bash
faust2alsa file.dsp        # ALSA (Linux)
faust2jack file.dsp        # Jack Audio
```

### Generate C++ code
```bash
faust -o output.cpp file.dsp
```

## Example DSP Files

### Simple Oscillator
```faust
import("stdfaust.lib");

freq = hslider("Frequency", 440, 20, 2000, 1);
gain = hslider("Gain", 0.5, 0, 1, 0.01);

process = os.osc(freq) * gain;
```

### Filtered Noise
```faust
import("stdfaust.lib");

cutoff = hslider("Cutoff", 1000, 20, 20000, 1);
resonance = hslider("Q", 1, 0.5, 10, 0.1);

process = no.noise : fi.resonlp(cutoff, resonance, 1) * 0.5;
```

### Stereo Delay
```faust
import("stdfaust.lib");

deltime = hslider("Delay", 0.5, 0, 2, 0.01);
feedback = hslider("Feedback", 0.5, 0, 0.99, 0.01);

process = +~ (@(deltime * ma.SR) * feedback) <: _,_;
```

## Libraries Reference

Faust includes several standard libraries:
- `stdfaust.lib` - Includes all standard libraries
- `oscillators.lib` (os.*) - Oscillators
- `filters.lib` (fi.*) - Filters
- `maths.lib` (ma.*) - Math functions
- `signals.lib` (si.*) - Signal processors
- `noises.lib` (no.*) - Noise generators
- `envelopes.lib` (en.*) - Envelope generators
- `effects.lib` (ef.*) - Audio effects

## Integration with ChucK

You can use Faust alongside ChucK:

1. **ChucK for composition/sequencing**
2. **Faust for DSP algorithms**

Export Faust to Max/MSP or SuperCollider and then use OSC to communicate with ChucK.

## Resources

- Official website: https://faust.grame.fr/
- Online editor: https://faustide.grame.fr/
- Examples: https://github.com/grame-cncm/faustlibraries
- Documentation: https://faustdoc.grame.fr/

## Workflow Integration

This setup mirrors your ChucK workflow:
- `run_loopstation.sh` → runs ChucK programs
- `run_faust.sh` → runs Faust programs

Both scripts handle terminal cleanup and provide easy execution!

## Tips

1. Start with simple examples and build complexity gradually
2. Use the online IDE (faustide.grame.fr) for quick prototyping
3. Check out the Faust libraries for pre-built DSP components
4. Use faust2svg to visualize your signal flow
5. Combine Faust with ChucK for powerful audio systems

Happy coding! 🎵
