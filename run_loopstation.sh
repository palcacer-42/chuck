#!/bin/zsh
# Wrapper script to run ChucK programs and always restore terminal

# Save original terminal settings
stty_orig=$(stty -g)

# Function to restore terminal on exit
cleanup() {
    echo ""
    echo "Restoring terminal..."
    stty "$stty_orig"
    stty sane
    echo "Terminal restored!"
}

# Set trap to always run cleanup on exit (normal, interrupt, terminate)
trap cleanup EXIT INT TERM

# Run ChucK with the loopstation
chuck loopstationULTIMATE.ck

# cleanup will run automatically when script exits
