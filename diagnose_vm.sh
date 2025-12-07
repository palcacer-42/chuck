#!/bin/bash
# Diagnostic script for VM audio setup

echo "=== ChucK VM Audio Diagnostics ==="
echo ""

# Check if ChucK is installed
echo "1. Checking ChucK installation..."
if command -v chuck &> /dev/null; then
    chuck --version
    echo "✓ ChucK is installed"
else
    echo "✗ ChucK not found. Install with: sudo pacman -S chuck"
    exit 1
fi

echo ""
echo "2. Probing audio devices..."
chuck --probe

echo ""
echo "3. Checking JACK status..."
if command -v jack_control &> /dev/null; then
    jack_control status 2>/dev/null || echo "JACK server not running (this is OK for VM mode)"
else
    echo "JACK not installed (this is OK for VM mode)"
fi

echo ""
echo "4. Checking audio systems..."
if command -v pactl &> /dev/null; then
    echo "✓ PulseAudio found"
    pactl info | grep "Server Name" || true
elif command -v pipewire &> /dev/null; then
    echo "✓ PipeWire found"
else
    echo "⚠ No audio server detected"
    echo "  Consider installing: sudo pacman -S pulseaudio pulseaudio-alsa"
fi

echo ""
echo "5. Recommended run commands:"
echo ""
echo "   Option 1 (normal):"
echo "   chuck loopstationVM.ck"
echo ""
echo "   Option 2 (mono audio):"
echo "   chuck --out:1 --in:1 loopstationVM.ck"
echo ""
echo "   Option 3 (silent mode):"
echo "   chuck --silent loopstationVM.ck"
echo ""
echo "6. Test ChucK basic functionality..."
echo "   Creating simple test..."
if echo "SinOsc s => dac; 220 => s.freq; 0.3 => s.gain; 500::ms => now;" | chuck --silent 2>&1 | grep -q "error"; then
    echo "⚠ ChucK may have issues"
else
    echo "✓ ChucK can run code"
fi

echo ""
echo "=== Diagnostic complete ==="
echo "If JACK errors appear, use: ./run_vm_loopstation.sh"
