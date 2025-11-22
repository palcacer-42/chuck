# Faust Loopstation - Terminal Control Guide

## Quick Start

### Option 1: Interactive Controller (Easiest)

Terminal 1 - Start the loopstation:
```bash
./run_faust_loopstation.sh
```

Terminal 2 - Interactive control:
```bash
./run_loopstation_interactive.sh
```

Then use these keys:
- `1-5` : Volume presets (quiet to max)
- `r` : Reverb ON, `R` : Reverb OFF
- `d` : Delay ON, `D` : Delay OFF  
- `x` : Distortion ON, `X` : Distortion OFF
- `p` : Pan left, `P` : Pan right, `0` : Center
- `l` : Short loop (2s), `L` : Long loop (8s)
- `c` : Custom parameter mode
- `q` : Quit

### Option 2: Manual OSC Control

Install python-osc first:
```bash
pip3 install python-osc
```

Start loopstation:
```bash
./loopstation_osc
```

In another terminal, send commands:
```bash
# Add reverb
python3 control_loopstation.py --reverb-mix 0.5 --reverb-size 0.8

# Add delay
python3 control_loopstation.py --delay-mix 0.6 --delay-time 500 --delay-feedback 0.4

# Add distortion
python3 control_loopstation.py --distortion 0.7

# Adjust volumes
python3 control_loopstation.py --master 0.8 --wet 0.9 --dry 0.3

# Pan controls
python3 control_loopstation.py --pan -0.5  # Pan left
python3 control_loopstation.py --pan 0.5   # Pan right

# Loop length
python3 control_loopstation.py --loop-length 6.0
```

## All Available Parameters

| Parameter | Range | Description |
|-----------|-------|-------------|
| `--input` | 0-1 | Input gain |
| `--wet` | 0-1 | Loop wet mix |
| `--dry` | 0-1 | Direct dry mix |
| `--master` | 0-1 | Master volume |
| `--reverb-mix` | 0-1 | Reverb amount |
| `--reverb-size` | 0-1 | Room size |
| `--reverb-damp` | 0-1 | High frequency damping |
| `--delay-mix` | 0-1 | Delay amount |
| `--delay-time` | 10-2000 | Delay time in milliseconds |
| `--delay-feedback` | 0-0.95 | Delay feedback |
| `--distortion` | 0-0.9 | Distortion drive |
| `--pan` | -1 to 1 | Stereo pan (left to right) |
| `--loop-length` | 0.5-10 | Loop buffer length in seconds |

## Example Presets

### Ambient Pad
```bash
python3 control_loopstation.py --loop-length 8.0 --reverb-mix 0.7 --reverb-size 0.9 --delay-mix 0.4 --delay-time 750 --delay-feedback 0.6
```

### Rhythmic Echo
```bash
python3 control_loopstation.py --loop-length 2.0 --delay-mix 0.8 --delay-time 125 --delay-feedback 0.7 --distortion 0.3
```

### Clean Loop
```bash
python3 control_loopstation.py --loop-length 4.0 --reverb-mix 0.0 --delay-mix 0.0 --distortion 0.0 --wet 1.0 --dry 0.2
```

### Lo-Fi Texture
```bash
python3 control_loopstation.py --distortion 0.6 --reverb-mix 0.5 --reverb-damp 0.8 --delay-mix 0.3
```

## Tips

1. **Start simple**: Begin with just the loop running, then add effects gradually
2. **Multiple commands**: Chain parameters together in one command
3. **Background mode**: Run `./loopstation_osc &` to run in background
4. **Kill process**: `killall loopstation_osc` or press Ctrl+C

## Comparison to ChucK Version

### Faust Version ✓
- Clean effects chain
- OSC control
- Lightweight
- Fast compilation

### ChucK Version ✓
- Multiple overdub tracks
- Precise timing/sync
- HID support (foot pedals)
- Visual LED feedback
- Record/play/stop buttons

**Best approach**: Use ChucK for the looper logic, Faust for effects!
