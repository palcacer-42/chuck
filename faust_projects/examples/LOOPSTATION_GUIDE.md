# Faust Loop Station - User Guide

## Overview
A real-time multi-track loop station built in Faust with GUI controls. Features 4 independent loop tracks with individual playback and gain controls, built-in metronome, and optional reverb.

## Features
- **4 Independent Loop Tracks** - Main loop + 3 overdubs
- **GUI Interface** - Visual controls for all parameters
- **Metronome** - Adjustable BPM with click track
- **Individual Gain Control** - Per-loop volume adjustment
- **Reverb Effect** - Optional ambient reverb
- **4-Beat Loops** - Fixed 4-beat loop length (adjustable via BPM)

## Quick Start

### 1. Compile and Run

**⚠️ Important:** The GUI version (faust2caqt) currently has code signing issues on macOS. Use the console version instead:

```bash
cd faust_projects/examples
faust2caconsole loopstation.dsp
/Users/palcacer/Documents/CODE/Chuck/faust_projects/examples/loopstation
```

**Known Issues:**
- The faust2caqt (Qt GUI version) fails with code signature errors on macOS 26.1
- The console version works but has no GUI controls
- Type 'q' to quit the console version

**Alternative - Use Faust Web IDE:**
1. Go to https://faustide.grame.fr/
2. Copy and paste the loopstation.dsp code
3. Run in browser with full GUI controls

### 2. Basic Workflow

#### Record Main Loop (Loop 1)
1. Set your desired BPM (default: 120)
2. Enable **Metronome** if desired
3. Click **Loop 1 > Record** button
4. Play/sing for 4 beats
5. Recording automatically stops after 4 beats
6. Check **Loop 1 > Play** to hear it

#### Add Overdubs (Loops 2-4)
1. Make sure Loop 1 is playing
2. Click **Loop 2 > Record**
3. You'll hear Loop 1 while recording
4. Play your overdub for 4 beats
5. Check **Loop 2 > Play** to add it to the mix
6. Repeat for Loops 3 and 4

### 3. Controls Reference

#### Master Section (Top)
- **BPM**: Set tempo (40-300 BPM)
- **Input Gain**: Adjust recording input level (0-1.5x)
- **Output Gain**: Master volume (0-1.5x)
- **Metronome**: Enable/disable click track
- **Click Volume**: Metronome volume (0-1)

#### Loop Sections (1-4)
Each loop has:
- **Record**: Click to record 4 beats
- **Play**: Toggle playback on/off
- **Gain**: Individual loop volume (0-1.5x)

#### FX Section
- **Reverb**: Add ambient reverb (0-1)

## Tips & Tricks

### Recording Strategy
1. **Start with drums/percussion** - Loop 1 should be your foundation
2. **Use metronome** - Keep perfect time while recording Loop 1
3. **Layer gradually** - Add one overdub at a time
4. **Adjust gains** - Balance loops using individual gain knobs
5. **Mute loops** - Uncheck "Play" to remove loops from mix temporarily

### Timing
- All loops are exactly **4 beats** long
- Loop length = (60 / BPM) × 4 seconds
- Examples:
  - 120 BPM = 2 second loops
  - 90 BPM = 2.67 second loops
  - 140 BPM = 1.71 second loops

### Live Performance
- **Pre-set BPM** before starting
- **Practice transitions** between recording loops
- **Use gain for dynamics** - fade loops in/out
- **Reverb for atmosphere** - add space to the mix

### Recording Multiple Takes
To re-record a loop:
1. Uncheck the loop's "Play" checkbox
2. Click "Record" again
3. The new recording will overwrite the old one

## Workflow Comparison with ChucK Version

| Feature | ChucK Version | Faust Version |
|---------|---------------|---------------|
| Interface | Terminal/keyboard | GUI with knobs/buttons |
| Loop Count | 10 overdubs | 4 loops total |
| Timing | Free or 4-beat | 4-beat only |
| Tap Tempo | Yes | No (manual BPM) |
| LED Ring | Yes | No (visual GUI instead) |
| WAV Export | Yes | Via host DAW |
| Redo Last | Yes | Re-record any loop |
| Toggle Loops | Number keys | Play checkboxes |
| Effects | None | Reverb |

## Advanced Usage

### Integration with DAW
Since this compiles to a native app, you can:
1. Record output with system audio capture (like BlackHole)
2. Or compile to VST/AU plugin for DAW use:
```bash
faust2vst loopstation.dsp    # VST plugin
faust2au loopstation.dsp     # Audio Unit (macOS)
```

### Customization
Edit `loopstation.dsp` to:
- Change max loop length (line: `max_delay = 480000`)
- Adjust number of loops (duplicate loop sections)
- Modify BPM range (line: `bpm = hslider(...)`)
- Add more effects (after line: `simple_reverb`)

## Troubleshooting

### Compilation fails (Code Signature Invalid)
**Problem:** `faust2caqt` creates an app but it crashes with "Code Signature Invalid"
**Solution:** 
- Use `faust2caconsole` instead (no GUI but works)
- Or use Faust Web IDE for GUI version
- Qt/macOS version mismatch causes signing issues

### Console version has no GUI controls
**Problem:** The caconsole version runs but you can't control parameters
**Solution:**
- Use Faust Web IDE (https://faustide.grame.fr/) for full GUI
- Or edit the .dsp file to set default values for parameters

### No audio recording
- Check Input Gain is > 0
- Verify microphone permissions in System Preferences
- Ensure correct audio input device selected

### Clicks/pops in loops
- Lower input gain to avoid clipping
- Check that loop length matches your recording
- BPM changes will affect existing loops!

### Loops out of sync
- All loops use same BPM
- Don't change BPM after recording
- Re-record loops if BPM changed

## Keyboard Shortcuts
(Depends on compilation target - Qt interfaces support keyboard shortcuts)
- Space: Can be mapped to record/play
- Numbers: Can be mapped to loop toggles
- Check your compiled app's menu for shortcuts

## Performance Notes
- CPU usage depends on number of active loops
- Reverb adds processing overhead
- Recommended buffer size: 256-512 samples
- Sample rate: 44.1kHz or 48kHz

## Next Steps
- Try the basic hello_faust.dsp first to test your setup
- Experiment with different BPMs and musical styles
- Layer rhythmic patterns with melodic content
- Record performances to your DAW

Enjoy looping! 🎵
