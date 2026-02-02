#!/bin/bash
# ============================================================
# Loopstation RPI Setup Script
# For Patchbox OS / Raspberry Pi 4
# ============================================================

echo "=== Loopstation RPI Setup ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# ============================================================
# 1. Check if we're on Raspberry Pi
# ============================================================
echo "1. Checking system..."
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model)
    ok "Running on: $MODEL"
else
    warn "Not a Raspberry Pi (or can't detect model)"
fi

# ============================================================
# 2. Check/Install dependencies
# ============================================================
echo ""
echo "2. Checking dependencies..."

# Check for ChucK
if command -v chuck &> /dev/null; then
    CHUCK_VER=$(chuck --version 2>&1 | head -1)
    ok "ChucK installed: $CHUCK_VER"
else
    warn "ChucK not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y chuck
    if command -v chuck &> /dev/null; then
        ok "ChucK installed successfully"
    else
        fail "Failed to install ChucK"
        exit 1
    fi
fi

# Check for JACK
if command -v jackd &> /dev/null; then
    ok "JACK installed"
else
    warn "JACK not found. Installing..."
    sudo apt-get install -y jackd2
fi

# ============================================================
# 3. List audio devices
# ============================================================
echo ""
echo "3. Available audio devices:"
echo "   --- PLAYBACK (output) ---"
aplay -l 2>/dev/null | grep -E "^card|^  " | head -10
echo ""
echo "   --- CAPTURE (input) ---"
arecord -l 2>/dev/null | grep -E "^card|^  " | head -10

# ============================================================
# 4. Detect USB audio interface
# ============================================================
echo ""
echo "4. Detecting USB audio interface..."

# Look for USB audio devices
USB_CARD=$(aplay -l 2>/dev/null | grep -i "usb" | head -1 | sed 's/card \([0-9]*\):.*/\1/')
if [ -n "$USB_CARD" ]; then
    USB_NAME=$(aplay -l 2>/dev/null | grep "card $USB_CARD:" | sed 's/.*: \(.*\) \[.*/\1/')
    ok "Found USB audio: card $USB_CARD ($USB_NAME)"
    AUDIO_DEVICE="hw:$USB_CARD"
else
    warn "No USB audio found, using default (hw:0)"
    AUDIO_DEVICE="hw:0"
fi

# ============================================================
# 5. Check if JACK is already running
# ============================================================
echo ""
echo "5. Checking JACK status..."

if pgrep -x "jackd" > /dev/null; then
    ok "JACK is already running"
    JACK_RUNNING=1
else
    warn "JACK is not running"
    JACK_RUNNING=0
fi

# ============================================================
# 6. Create run script
# ============================================================
echo ""
echo "6. Creating run script..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cat > "$SCRIPT_DIR/run_loopstation_rpi.sh" << 'RUNSCRIPT'
#!/bin/bash
# Run Loopstation on Raspberry Pi
# Usage: ./run_loopstation_rpi.sh [audio_device]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Default audio device (change if needed)
AUDIO_DEVICE="${1:-hw:0}"

echo "=== Loopstation RPI ==="
echo "Audio device: $AUDIO_DEVICE"
echo ""

# Check if JACK is running
if ! pgrep -x "jackd" > /dev/null; then
    echo "Starting JACK..."
    # Start JACK with low latency settings for Raspberry Pi
    jackd -d alsa -d "$AUDIO_DEVICE" -r 44100 -p 256 -n 2 &
    JACK_PID=$!
    sleep 2
    
    if ! pgrep -x "jackd" > /dev/null; then
        echo "JACK failed to start. Trying without JACK..."
        # Kill failed jackd
        kill $JACK_PID 2>/dev/null
        
        # Run ChucK with ALSA directly
        echo "Running with ALSA..."
        chuck --srate:44100 --bufsize:512 loopstationRPI.ck
        exit $?
    fi
    echo "JACK started (PID: $JACK_PID)"
fi

echo "Starting loopstation..."
echo "Press Ctrl+C to stop"
echo ""

# Run ChucK (it will auto-connect to JACK if available)
chuck --srate:44100 --bufsize:256 loopstationRPI.ck

# Cleanup
echo ""
echo "Loopstation stopped."
RUNSCRIPT

chmod +x "$SCRIPT_DIR/run_loopstation_rpi.sh"
ok "Created run_loopstation_rpi.sh"

# ============================================================
# 7. Show MIDI devices (for BlueTurn pedal)
# ============================================================
echo ""
echo "7. MIDI/HID devices:"
if command -v aconnect &> /dev/null; then
    aconnect -l 2>/dev/null | head -15
else
    echo "   (aconnect not available)"
fi

# Check for keyboards (HID)
echo ""
echo "   Keyboard/HID devices:"
ls -la /dev/input/by-id/ 2>/dev/null | grep -i keyboard || echo "   No keyboards found"

# ============================================================
# 8. Summary
# ============================================================
echo ""
echo "============================================================"
echo "Setup complete!"
echo ""
echo "To run the loopstation:"
echo "  cd $SCRIPT_DIR"
echo "  ./run_loopstation_rpi.sh"
echo ""
echo "Or with specific audio device:"
echo "  ./run_loopstation_rpi.sh hw:1"
echo ""
echo "Recommended JACK settings for Raspberry Pi 4:"
echo "  Sample rate: 44100 Hz"
echo "  Buffer size: 256 samples (~6ms latency)"
echo "  Periods: 2"
echo "============================================================"
