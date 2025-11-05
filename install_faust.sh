#!/bin/zsh
# Faust Installation and Setup Script for macOS

set -e  # Exit on error

echo "=================================="
echo "Faust Installation Workflow"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Homebrew is installed
echo "${BLUE}Step 1: Checking for Homebrew...${NC}"
if ! command -v brew &> /dev/null; then
    echo "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "${GREEN}✓ Homebrew is installed${NC}"
fi
echo ""

# Update Homebrew
echo "${BLUE}Step 2: Updating Homebrew...${NC}"
brew update
echo "${GREEN}✓ Homebrew updated${NC}"
echo ""

# Install Faust
echo "${BLUE}Step 3: Installing Faust...${NC}"
if ! command -v faust &> /dev/null; then
    brew install faust
    echo "${GREEN}✓ Faust installed successfully${NC}"
else
    echo "${GREEN}✓ Faust is already installed${NC}"
    echo "Current version: $(faust --version)"
fi
echo ""

# Install additional useful packages
echo "${BLUE}Step 4: Installing additional audio tools...${NC}"

# Install Qt (for faust2jaqt and other GUI targets)
if ! brew list qt &> /dev/null; then
    echo "Installing Qt for GUI support..."
    brew install qt
fi

# Install Jack Audio (optional but useful for audio routing)
if ! brew list jack &> /dev/null; then
    echo "Installing Jack Audio Connection Kit..."
    brew install jack
fi

echo "${GREEN}✓ Additional tools installed${NC}"
echo ""

# Create a working directory structure
echo "${BLUE}Step 5: Setting up Faust workspace...${NC}"
FAUST_DIR="$(pwd)/faust_projects"
mkdir -p "$FAUST_DIR"/{examples,lib,builds}
echo "${GREEN}✓ Created directory structure:${NC}"
echo "  $FAUST_DIR/examples   - For your Faust DSP files"
echo "  $FAUST_DIR/lib        - For custom libraries"
echo "  $FAUST_DIR/builds     - For compiled outputs"
echo ""

# Create a sample Faust file
echo "${BLUE}Step 6: Creating sample Faust file...${NC}"
cat > "$FAUST_DIR/examples/hello_faust.dsp" << 'EOF'
// Simple sine wave oscillator
// Usage: faust2caqt hello_faust.dsp && ./hello_faust

import("stdfaust.lib");

freq = hslider("Frequency", 440, 20, 2000, 1);
gain = hslider("Gain", 0.5, 0, 1, 0.01) : si.smoo;

process = os.osc(freq) * gain;
EOF
echo "${GREEN}✓ Created hello_faust.dsp${NC}"
echo ""

# Create a more complex example
cat > "$FAUST_DIR/examples/simple_filter.dsp" << 'EOF'
// Simple lowpass filter with resonance
import("stdfaust.lib");

freq = hslider("Cutoff[style:knob]", 1000, 20, 20000, 1) : si.smoo;
q = hslider("Resonance[style:knob]", 1, 0.5, 10, 0.1) : si.smoo;
gain = hslider("Gain[style:knob]", 0.5, 0, 1, 0.01) : si.smoo;

process = no.noise * gain : fi.resonlp(freq, q, 1);
EOF
echo "${GREEN}✓ Created simple_filter.dsp${NC}"
echo ""

# Verify installation
echo "${BLUE}Step 7: Verifying installation...${NC}"
echo "Faust version: $(faust --version)"
echo "Faust location: $(which faust)"
echo ""
echo "${GREEN}Available Faust architectures (faust2* commands):${NC}"
ls -1 $(dirname $(which faust))/faust2* | head -20
echo ""

# Print usage instructions
echo "${GREEN}=================================="
echo "Installation Complete!"
echo "==================================${NC}"
echo ""
echo "${BLUE}Quick Start Guide:${NC}"
echo ""
echo "1. Your Faust workspace is at: $FAUST_DIR"
echo ""
echo "2. Try the example files:"
echo "   cd $FAUST_DIR/examples"
echo ""
echo "3. Compile and run with CoreAudio/Qt (macOS):"
echo "   faust2caqt hello_faust.dsp"
echo "   ./hello_faust"
echo ""
echo "4. Or compile to other targets:"
echo "   faust2jack hello_faust.dsp      # Jack Audio"
echo "   faust2supercollider hello_faust.dsp  # SuperCollider"
echo "   faust2max6 hello_faust.dsp      # Max/MSP"
echo "   faust2vst hello_faust.dsp       # VST plugin"
echo ""
echo "5. For web audio:"
echo "   faust2wasm hello_faust.dsp"
echo ""
echo "6. View DSP diagram:"
echo "   faust2svg hello_faust.dsp && open hello_faust-svg/process.svg"
echo ""
echo "${YELLOW}Tip: Run './run_faust.sh' to quickly test Faust programs${NC}"
echo ""
