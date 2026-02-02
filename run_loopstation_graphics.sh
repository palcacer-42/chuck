#!/bin/bash
# ============================================================
# Run Loopstation GRAPHICS on Raspberry Pi / Patchbox OS
# Handles JACK startup, audio device, and graphics displays
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Loopstation RPI [GRAPHICS] ==="
echo ""

# ============================================================
# 1. Find audio device
# ============================================================
echo "Detecting audio devices..."

# Try to find USB audio first, fall back to default
USB_CARD=$(aplay -l 2>/dev/null | grep -i "usb" | head -1 | sed 's/card \([0-9]*\):.*/\1/')
if [ -n "$USB_CARD" ]; then
    AUDIO_DEVICE="hw:$USB_CARD"
    echo -e "${GREEN}Found USB audio: $AUDIO_DEVICE${NC}"
else
    # Use first available card
    FIRST_CARD=$(aplay -l 2>/dev/null | grep "^card" | head -1 | sed 's/card \([0-9]*\):.*/\1/')
    AUDIO_DEVICE="hw:${FIRST_CARD:-0}"
    echo -e "${YELLOW}Using default audio: $AUDIO_DEVICE${NC}"
fi

# Allow override from command line
if [ -n "$1" ]; then
    AUDIO_DEVICE="$1"
    echo "Using specified device: $AUDIO_DEVICE"
fi

# ============================================================
# 2. Stop any existing JACK
# ============================================================
if pgrep -x "jackd" > /dev/null; then
    echo "Stopping existing JACK server..."
    killall jackd 2>/dev/null
    sleep 1
fi

# ============================================================
# 3. Start JACK with proper settings
# ============================================================
echo ""
echo "Starting JACK audio server..."

# JACK settings for Raspberry Pi 4
# -d alsa: use ALSA backend
# -d hw:X: use specific device
# -r 44100: sample rate
# -p 512: buffer size (larger = more stable, higher latency)
# -n 2: periods
# -S: force 16-bit (more compatible)

jackd -d alsa -d "$AUDIO_DEVICE" -r 44100 -p 512 -n 2 -S &
JACK_PID=$!
sleep 2

# Check if JACK started successfully
if ! pgrep -x "jackd" > /dev/null; then
    echo -e "${YELLOW}JACK failed to start. Trying with mono output...${NC}"
    
    # Try with mono output (some USB devices are mono)
    jackd -d alsa -d "$AUDIO_DEVICE" -r 44100 -p 512 -n 2 -S -o 1 -i 1 &
    JACK_PID=$!
    sleep 2
    
    if ! pgrep -x "jackd" > /dev/null; then
        echo -e "${YELLOW}JACK still failed. Running ChucK with ALSA directly...${NC}"
        echo ""
        
        # Run ChucK without JACK using ALSA
        # --dac:X specifies output device, --adc:X specifies input
        # Extract card number from hw:X
        CARD_NUM=$(echo "$AUDIO_DEVICE" | sed 's/hw://')
        
        echo "Running: chuck --dac:$CARD_NUM --adc:$CARD_NUM --srate:44100 --bufsize:512 loopstationRPI_graphics.ck"
        echo ""
        chuck --dac:$CARD_NUM --adc:$CARD_NUM --srate:44100 --bufsize:512 loopstationRPI_graphics.ck
        exit $?
    fi
fi

echo -e "${GREEN}JACK started successfully (PID: $JACK_PID)${NC}"

# ============================================================
# 4. Show JACK status
# ============================================================
echo ""
echo "JACK connections:"
jack_lsp 2>/dev/null | head -10

# ============================================================
# 5. Start Display Driver (touchscreen or terminal fallback)
# ============================================================
DISPLAY_PID=""
echo ""

# Try touchscreen display first (for 4-inch RPi screen)
if [ -f "display_touchscreen.py" ]; then
    echo "Starting touchscreen display..."
    python3 display_touchscreen.py &
    DISPLAY_PID=$!
    sleep 1
# Fall back to terminal display
elif [ -f "display_driver.py" ]; then
    echo "Starting terminal display..."
    python3 display_driver.py --terminal &
    DISPLAY_PID=$!
    sleep 0.5
fi

# ============================================================
# 6. Run ChucK
# ============================================================
echo ""
echo "Starting loopstation with graphics..."
echo "Press Ctrl+C to stop"
echo "============================================"
echo ""

# Run ChucK (will auto-connect to JACK)
chuck --srate:44100 --bufsize:256 loopstationRPI_graphics.ck
CHUCK_EXIT=$?

# ============================================================
# 7. Cleanup
# ============================================================
echo ""
echo "Stopping..."

# Stop display driver
if [ -n "$DISPLAY_PID" ]; then
    kill $DISPLAY_PID 2>/dev/null
fi

# Stop JACK
kill $JACK_PID 2>/dev/null
killall jackd 2>/dev/null

# Clean up state file
rm -f /tmp/loopstation_state.json

echo "Loopstation stopped."
exit $CHUCK_EXIT
