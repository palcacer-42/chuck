#!/bin/bash
# Load a ChucK Loopstation session file

if [ $# -eq 0 ]; then
    echo "Usage: ./load_session.sh <session_file.cks>"
    echo ""
    echo "Available sessions:"
    ls -1t session_*.cks 2>/dev/null | head -10
    exit 1
fi

SESSION_FILE="$1"

if [ ! -f "$SESSION_FILE" ]; then
    echo "Error: Session file not found: $SESSION_FILE"
    exit 1
fi

echo "Loading session: $SESSION_FILE"
chuck loopstationULTIMATE.ck:"$SESSION_FILE"
