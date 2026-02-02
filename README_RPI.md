# Loopstation RPI - Raspberry Pi / Patchbox OS Version

## The Problem

The original `loopstationULTIMATE.ck` uses Unicode characters (em-dashes, circle symbols, arrows) that the ChucK parser on Patchbox OS / older ChucK versions cannot handle.

### Error you might see:
```
[loopstation]:line(1).char(1): illegal token
[loopstation]:line(1).char(2): illegal token
...
```

## Solution: loopstationRPI.ck

The `loopstationRPI.ck` file is an **ASCII-only** version of the loopstation with all Unicode characters converted:

| Original | ASCII Replacement |
|----------|-------------------|
| `–` (em-dash) | `-` (hyphen) |
| `○` (empty circle) | `o` |
| `●` (filled circle) | `*` |
| `✓` (checkmark) | `[OK]` |
| `→` (arrow) | `->` |
| `…` (ellipsis) | `...` |

## Installation on Patchbox OS

### 1. Install ChucK (if not already installed)
```bash
sudo apt update
sudo apt install chuck
```

### 2. Verify ChucK version
```bash
chuck --version
```

### 3. Check audio devices
```bash
chuck --probe
```

### 4. Run the loopstation
```bash
# With default audio
chuck loopstationRPI.ck

# If you need to specify ALSA backend
chuck --dac:1 --adc:1 loopstationRPI.ck
```

## Troubleshooting

### No sound output
- Check that your audio interface is recognized: `aplay -l`
- Try specifying the device: `chuck --dac:X loopstationRPI.ck` (replace X with device number)

### HID (BlueTurn pedal) not working
- Check HID devices: `chuck --probe` and look for keyboards/HID
- BlueTurn sends Page Up/Down keys - may need different key codes on Linux

### MIDI controller not found
- Check MIDI devices: `aconnect -l`
- Verify APC Mini is recognized: `amidi -l`

## Converting Files Yourself

If you modify `loopstationULTIMATE.ck` and need to reconvert:

```bash
# Remove Unicode characters
sed 's/–/-/g; s/○/o/g; s/●/*/g; s/✓/[OK]/g; s/→/->/g; s/…/.../g' loopstationULTIMATE.ck > loopstationRPI.ck

# Verify it's ASCII
file loopstationRPI.ck
# Should output: loopstationRPI.ck: ASCII text
```

## Features (same as ULTIMATE version)

- Free Mode and Measure Mode recording
- Up to 10 overdub layers
- iRig BlueTurn pedal support (via HID)
- Akai APC Mini MIDI controller support (optional)
- Session save/load
- Per-track effects (speed, reverse, octave down, pan)
- Visual LED display in terminal

## Controls

| Key | Function |
|-----|----------|
| `m` | Toggle Measure/Free mode |
| `r` | Record/Stop recording |
| `p` | Play/Stop |
| `o` | Add overdub |
| `u` | Undo last overdub |
| `e` | Erase all |
| `t` | Tap tempo |
| `b` | Set beat length |
| `0-9` | Toggle track on/off |
| `q` | Quit |
| `x/ESC` | Emergency exit |
