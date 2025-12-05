#!/bin/bash
# Run Faust Loopstation with OSC control

cd "$(dirname "$0")"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║      FAUST LOOPSTATION - Starting with OSC Control        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Starting loopstation on OSC port 5510..."
echo "Open another terminal and run: ./run_loopstation_interactive.sh"
echo ""
echo "Or control manually with:"
echo "  python3 control_loopstation.py --reverb-mix 0.5"
echo "  python3 control_loopstation.py --delay-mix 0.4 --delay-time 500"
echo ""
echo "Press Ctrl+C to stop"
echo "─────────────────────────────────────────────────────────────"
echo ""

./loopstation_osc
