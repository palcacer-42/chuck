#!/bin/bash
# Run Loopstation VM Edition
# Optimized for Virtual Machines (UTM Arch Linux, etc.)

echo "=== ChucK Loopstation VM Edition ==="
echo ""
echo "Running with minimal audio requirements..."
echo "This version works without:"
echo "  - JACK server"
echo "  - Real audio input/output devices"
echo "  - HID/MIDI controllers"
echo ""
echo "Press 't' to toggle test tone (440Hz sine wave)"
echo "Press Ctrl+C to stop"
echo ""

# Run ChucK with VM-friendly settings
# Using --silent mode OR minimal channel configuration
chuck loopstationVM.ck

# Alternative: If the above doesn't work, try:
# chuck --out:1 --in:1 loopstationVM.ck
# Or completely silent:
# chuck --silent loopstationVM.ck
