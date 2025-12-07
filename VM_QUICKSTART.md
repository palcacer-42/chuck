# VM Files Quick Reference

## Files Created for VM Support

### Main Files
1. **loopstationVM.ck** (64KB)
   - VM-optimized loopstation code
   - Graceful handling of missing audio/JACK/HID
   - Built-in test tone generator
   - Original file (`loopstationULTIMATE.ck`) remains untouched

### Helper Scripts
2. **run_vm_loopstation.sh**
   - Main script to run the VM version
   - Handles audio device issues automatically

3. **diagnose_vm.sh**
   - Diagnostic tool to check your VM setup
   - Tests ChucK installation and audio availability
   - Recommends best run command for your system

4. **run_vm.sh**
   - Alternative runner with explicit dummy audio device
   - Use if standard mode fails

5. **run_vm_probe.sh**
   - Probes audio devices first, then runs with available devices
   - Good for debugging

6. **run_silent.sh**
   - Runs in completely silent mode (no audio at all)
   - Last resort for extremely limited VMs

### Documentation
7. **README_VM.md** (4.3KB)
   - Comprehensive VM edition documentation
   - Installation instructions for Arch Linux
   - Troubleshooting guide
   - Full keyboard controls reference

## Quick Start (Arch Linux VM)

```bash
# 1. Copy these files to your VM
scp loopstationVM.ck user@vm:/path/to/chuck/
scp run_vm_loopstation.sh user@vm:/path/to/chuck/
scp diagnose_vm.sh user@vm:/path/to/chuck/

# 2. On your VM, install ChucK
sudo pacman -S chuck

# 3. Run diagnostics
./diagnose_vm.sh

# 4. Start the loopstation
./run_vm_loopstation.sh
```

## Key Differences: Original vs VM Edition

| Feature | loopstationULTIMATE.ck | loopstationVM.ck |
|---------|------------------------|------------------|
| Audio I/O | Requires adc/dac | Optional, uses test tone |
| JACK Server | Required | Not required |
| HID (BlueTurn) | Enabled | Disabled in VM mode |
| MIDI (APC Mini) | Enabled | Disabled in VM mode |
| Test Tone | No | Yes (press 't') |
| Error Handling | Strict | Graceful fallback |
| Target Platform | Real hardware | Virtual machines |

## Toggling VM Mode

To disable VM mode after getting audio working:

Edit `loopstationVM.ck`, line 6:
```chuck
// Change from:
1 => int VM_MODE;

// To:
0 => int VM_MODE;
```

This re-enables all hardware features.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "JACK server not running" | Normal in VMs, use VM edition |
| "no audio output device" | Run with `./run_vm_loopstation.sh` |
| HID permission errors | VM mode disables HID automatically |
| Can't hear anything | Press 't' to enable test tone |
| Still crashes | Try `chuck --silent loopstationVM.ck` |

## Transfer to VM

### Using SCP
```bash
scp loopstationVM.ck *.sh README_VM.md user@vmhost:/destination/
```

### Using Shared Folder (UTM)
1. In UTM, enable shared folder in VM settings
2. Copy files to shared folder on host
3. Access from `/media/share/` in VM (location varies)

### Manual Copy-Paste
```bash
# On host
cat loopstationVM.ck

# In VM terminal
nano loopstationVM.ck
# Paste content, Ctrl+O to save, Ctrl+X to exit
```

## Testing Without Audio

```bash
# 1. Start loopstation
./run_vm_loopstation.sh

# 2. Enable test tone
# Press: t

# 3. Record the tone
# Press: r (wait a few seconds) r

# 4. Should loop automatically
# You should see the LED ring animation

# 5. Try overdub
# Press: o (wait) o

# 6. Stop playback
# Press: p
```

All core features work even without real audio!
