# Loopstation VM Edition

## Overview
This is a VM-optimized version of the ChucK Loopstation, designed to run in virtual machine environments (UTM Arch Linux, VirtualBox, VMware, etc.) where audio devices and JACK servers may not be available.

## Key Differences from Original

### VM Mode Features
- **Graceful audio device handling**: Won't crash if JACK server is missing
- **Test tone generator**: Built-in 440Hz sine wave for testing (press 't')
- **Disabled by default**: HID and MIDI controllers (to avoid device access errors)
- **Flexible audio**: Can run with minimal or no audio devices

### What Still Works
✅ All core loopstation functionality
✅ Recording and playback logic
✅ Overdub system (up to 10 tracks)
✅ Speed, pitch, and reverse effects
✅ Session save/load
✅ Keyboard controls
✅ Visual LED ring in terminal

### What's Disabled in VM Mode
❌ iRig BlueTurn HID support
❌ Akai APC Mini MIDI controller
❌ Real-time audio input (uses test tone instead)

## Running on Arch Linux VM (UTM)

### 1. Install ChucK
```bash
# On Arch Linux
sudo pacman -S chuck

# Or build from source
git clone https://github.com/ccrma/chuck.git
cd chuck/src
make linux-alsa
sudo make install
```

### 2. Transfer Files
Copy these files to your VM:
- `loopstationVM.ck`
- `run_vm_loopstation.sh`

### 3. Run the Loopstation

**Method 1: Using the helper script (recommended)**
```bash
chmod +x run_vm_loopstation.sh
./run_vm_loopstation.sh
```

**Method 2: Direct execution**
```bash
# Try normal mode first
chuck loopstationVM.ck

# If you get audio errors, try:
chuck --out:1 --in:1 loopstationVM.ck

# If JACK/audio is completely unavailable:
chuck --silent loopstationVM.ck
```

## Testing Without Audio Hardware

Since VMs often lack proper audio, use the built-in test tone:

1. Start the loopstation
2. Press `t` to enable test tone (440Hz sine wave)
3. Press `r` to start recording
4. Press `r` again to stop and loop
5. The tone should loop continuously

## Keyboard Controls

### Recording
- `r` - Start/Stop recording
- `o` - Overdub (add new layer)
- `u` - Undo last overdub
- `e` - Erase everything

### Playback
- `p` - Play/Stop
- `0-9` - Select/toggle track on/off

### Effects
- `+/-` - Speed up/down
- `=` - Reset speed to 1.0
- `v` - Reverse playback
- `{/}` - Track volume
- `[/]` - Master volume
- `,/.` - Pan left/right
- `/` - Reset pan to center

### Test Tone (VM Mode)
- `t` - Toggle test tone (440Hz sine wave)

### Session Management
- `s` - Quick save session
- `q` - Quit (with save options)

## Troubleshooting

### "JACK server not running"
This is normal in VMs. The VM edition handles this gracefully.

### "no audio output device"
The VM edition creates dummy audio paths. You can still test with the internal test tone.

### HID permission errors
The VM edition skips HID device initialization to avoid these errors.

### Audio doesn't work at all
1. Check if your VM has audio forwarding enabled
2. Try installing PulseAudio: `sudo pacman -S pulseaudio pulseaudio-alsa`
3. Or PipeWire: `sudo pacman -S pipewire pipewire-pulse pipewire-alsa`
4. Run in silent mode: `chuck --silent loopstationVM.ck`

## Converting to Non-VM Mode

If you want to disable VM mode (e.g., after getting audio working), edit `loopstationVM.ck`:

Change line 6 from:
```chuck
1 => int VM_MODE;
```

To:
```chuck
0 => int VM_MODE;
```

This will re-enable:
- Real audio input (adc)
- Audio output (dac)
- HID device support
- MIDI controller support

## Session Files

Sessions are saved as `.cks` (ChucK Session) files with all parameters:
- Loop timing and mode
- Overdub count and settings
- Effect parameters (speed, volume, pan, etc.)
- Track states (active/muted)

Load a session:
```bash
chuck loopstationVM.ck:sessionfile.cks
```

## Performance Notes

VM performance may vary:
- **CPU**: Loopstation is relatively lightweight
- **Audio latency**: May be higher in VMs
- **Storage**: Session files are small (< 1KB), audio exports can be large

## Original Version

The original `loopstationULTIMATE.ck` is untouched and provides:
- Full audio device support
- iRig BlueTurn HID pedal
- Akai APC Mini MIDI controller
- Optimized for native hardware

Use the original version on real hardware for best performance.

## Support

For issues specific to:
- **VM Edition**: Check this README
- **ChucK Installation**: https://chuck.cs.princeton.edu/
- **Original Loopstation**: See main project documentation
