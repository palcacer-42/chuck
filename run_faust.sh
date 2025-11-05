#!/bin/zsh
# Quick Faust runner script - compiles and runs Faust DSP files

# Save original terminal settings
stty_orig=$(stty -g)

# Function to restore terminal on exit
cleanup() {
    echo ""
    echo "Cleaning up..."
    stty "$stty_orig" 2>/dev/null
    stty sane 2>/dev/null
    # Kill any background audio processes if needed
    jobs -p | xargs kill 2>/dev/null
    echo "Done!"
}

# Set trap to always run cleanup on exit
trap cleanup EXIT INT TERM

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Faust is installed
if ! command -v faust &> /dev/null; then
    echo "${RED}Error: Faust is not installed${NC}"
    echo "Run ./install_faust.sh first"
    exit 1
fi

# Get DSP file from argument or use default
DSP_FILE="${1:-faust_projects/examples/hello_faust.dsp}"

if [[ ! -f "$DSP_FILE" ]]; then
    echo "${RED}Error: DSP file not found: $DSP_FILE${NC}"
    echo ""
    echo "Usage: ./run_faust.sh [dsp_file]"
    echo ""
    echo "Available examples:"
    if [[ -d "faust_projects/examples" ]]; then
        ls -1 faust_projects/examples/*.dsp 2>/dev/null || echo "  No examples found"
    fi
    exit 1
fi

# Get the base name without extension
BASE_NAME=$(basename "$DSP_FILE" .dsp)
DIR_NAME=$(dirname "$DSP_FILE")

echo "${BLUE}=================================="
echo "Faust Quick Runner"
echo "==================================${NC}"
echo "File: $DSP_FILE"
echo ""

# Compile with faust2caconsole (CoreAudio console for macOS)
echo "${YELLOW}Compiling with faust2caconsole...${NC}"
cd "$DIR_NAME" || exit 1

if faust2caconsole "$BASE_NAME.dsp"; then
    echo "${GREEN}✓ Compilation successful${NC}"
    echo ""
    echo "${YELLOW}Running $BASE_NAME...${NC}"
    echo "Press Ctrl+C to stop"
    echo ""
    echo "${BLUE}Controls:${NC}"
    echo "  - Runs in console (no GUI)"
    echo "  - Parameters are set in the .dsp file"
    echo ""
    
    # Run the compiled binary
    ./"$BASE_NAME"
else
    echo "${RED}✗ Compilation failed${NC}"
    echo ""
    echo "Trying alternative: faust2caqt (with Qt GUI)..."
    export QMAKEFLAGS="CONFIG+=sdk_no_version_check"
    if faust2caqt "$BASE_NAME.dsp" 2>/dev/null; then
        echo "${GREEN}✓ Compilation successful with Qt${NC}"
        echo ""
        echo "${YELLOW}Running $BASE_NAME...${NC}"
        echo "Press Ctrl+C to stop"
        echo ""
        ./"$BASE_NAME.app/Contents/MacOS/$BASE_NAME" 2>/dev/null || ./"$BASE_NAME"
    else
        echo "${RED}Both compilation methods failed${NC}"
        echo "Try compiling manually: cd $DIR_NAME && faust2caconsole $BASE_NAME.dsp"
        exit 1
    fi
fi

# cleanup will run automatically
