#!/usr/bin/env python3
"""
Display Configuration for Loopstation
Edit this file to customize your display setup.
"""

# ============================================================
# LED Strip Configuration
# ============================================================

LED_COUNT = 16          # Number of LEDs in your strip
LED_GPIO_PIN = 18       # GPIO pin (18 uses PWM, 10 uses SPI)
LED_BRIGHTNESS = 50     # 0-255 (lower = dimmer, saves power)

# ============================================================
# OLED Configuration
# ============================================================

OLED_I2C_ADDRESS = 0x3C  # Common addresses: 0x3C or 0x3D
OLED_WIDTH = 128
OLED_HEIGHT = 64

# ============================================================
# Color Schemes
# ============================================================

# RGB tuples (0-255, 0-255, 0-255)
COLORS = {
    # Loop position indicator
    'position':  (0, 255, 0),       # Bright green
    
    # Recording states
    'recording': (255, 0, 0),       # Red
    'overdub':   (255, 170, 0),     # Orange/Yellow
    
    # Playback states  
    'playing':   (0, 100, 255),     # Blue
    'stopped':   (50, 50, 50),      # Dim gray
    
    # Track indicators
    'track_on':  (0, 200, 0),       # Green
    'track_off': (30, 30, 30),      # Very dim
    'selected':  (255, 255, 255),   # White (selected track)
    
    # Background
    'off':       (0, 0, 0),
}

# ============================================================
# Update Timing
# ============================================================

STATE_FILE = "/tmp/loopstation_state.json"
UPDATE_INTERVAL = 0.05  # seconds (50ms = 20 FPS)
