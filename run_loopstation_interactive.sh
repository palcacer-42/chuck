#!/bin/bash
# Interactive Faust Loopstation Controller
# Control effects in real-time from terminal

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         FAUST LOOPSTATION - INTERACTIVE CONTROLLER        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Quick Controls:"
echo "  1-5    Volume presets"
echo "  r      Toggle reverb (off/on)"
echo "  d      Toggle delay (off/on)"
echo "  x      Toggle distortion (off/on)"
echo "  p      Pan (left/center/right)"
echo "  l      Loop length presets"
echo "  c      Custom value mode"
echo "  q      Quit"
echo ""
echo "─────────────────────────────────────────────────────────────"

# Check if python-osc is installed
if ! python3 -c "import pythonosc" 2>/dev/null; then
    echo "Installing python-osc..."
    pip3 install python-osc
fi

CONTROLLER="python3 $(dirname "$0")/control_loopstation.py"

while true; do
    echo -n "> "
    read -n 1 key
    echo ""
    
    case $key in
        1)
            echo "📢 Volume: Very quiet"
            $CONTROLLER --master 0.3
            ;;
        2)
            echo "📢 Volume: Quiet"
            $CONTROLLER --master 0.5
            ;;
        3)
            echo "📢 Volume: Medium"
            $CONTROLLER --master 0.7
            ;;
        4)
            echo "📢 Volume: Loud"
            $CONTROLLER --master 0.85
            ;;
        5)
            echo "📢 Volume: Maximum"
            $CONTROLLER --master 1.0
            ;;
        r)
            echo "🌊 Reverb ON (mix: 0.4, size: 0.7)"
            $CONTROLLER --reverb-mix 0.4 --reverb-size 0.7 --reverb-damp 0.5
            ;;
        R)
            echo "🌊 Reverb OFF"
            $CONTROLLER --reverb-mix 0.0
            ;;
        d)
            echo "⏱️  Delay ON (250ms, feedback: 0.5)"
            $CONTROLLER --delay-mix 0.4 --delay-time 250 --delay-feedback 0.5
            ;;
        D)
            echo "⏱️  Delay OFF"
            $CONTROLLER --delay-mix 0.0
            ;;
        x)
            echo "🔥 Distortion ON"
            $CONTROLLER --distortion 0.5
            ;;
        X)
            echo "🔥 Distortion OFF"
            $CONTROLLER --distortion 0.0
            ;;
        p)
            echo "⬅️  Pan: Left"
            $CONTROLLER --pan -0.7
            ;;
        P)
            echo "➡️  Pan: Right"
            $CONTROLLER --pan 0.7
            ;;
        0)
            echo "↔️  Pan: Center"
            $CONTROLLER --pan 0.0
            ;;
        l)
            echo "🔄 Loop: 2 seconds"
            $CONTROLLER --loop-length 2.0
            ;;
        L)
            echo "🔄 Loop: 8 seconds"
            $CONTROLLER --loop-length 8.0
            ;;
        c)
            echo ""
            echo "Custom Control Mode:"
            echo "Available parameters:"
            echo "  input, wet, dry, master, reverb-mix, reverb-size, reverb-damp"
            echo "  delay-mix, delay-time, delay-feedback, distortion, pan, loop-length"
            echo ""
            echo -n "Parameter name: "
            read param
            echo -n "Value: "
            read value
            $CONTROLLER --$param $value
            ;;
        q|Q)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "Unknown command. Press 'h' for help or 'q' to quit."
            ;;
    esac
done
