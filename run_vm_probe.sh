#!/bin/bash
# First probe available audio devices
echo "=== Available Audio Devices ==="
chuck --probe

echo ""
echo "=== Attempting to run with available device ==="
# Try to run with mono output (1 channel) if stereo fails
chuck --out:1 --in:1 loopstationULTIMATE.ck
