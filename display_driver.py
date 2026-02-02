#!/usr/bin/env python3
"""
Loopstation Display Driver
Reads state from /tmp/loopstation_state.json and updates hardware displays.

Supports:
- Terminal preview mode (--terminal)
- OLED display (SSD1306 via I2C)
- LED strip (WS2812B via GPIO)

Usage:
    python3 display_driver.py              # Auto-detect hardware
    python3 display_driver.py --terminal   # Terminal preview only
"""

import json
import time
import argparse
import os
import sys

# ============================================================
# Configuration
# ============================================================

STATE_FILE = "/tmp/loopstation_state.json"
UPDATE_INTERVAL = 0.05  # 50ms refresh rate

# LED colors (RGB tuples)
COLORS = {
    'off':       (0, 0, 0),
    'position':  (0, 255, 0),      # Green - current beat position
    'recording': (255, 0, 0),      # Red - recording
    'overdub':   (255, 170, 0),    # Yellow/Orange - overdubbing
    'playing':   (0, 100, 255),    # Blue - playing (dim)
    'track_on':  (0, 200, 0),      # Green - track active
    'track_off': (50, 50, 50),     # Dim gray - track muted
}

# ============================================================
# State Reader
# ============================================================

def read_state():
    """Read current loopstation state from JSON file."""
    try:
        if not os.path.exists(STATE_FILE):
            return None
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None

# ============================================================
# Terminal Display (works everywhere)
# ============================================================

class TerminalDisplay:
    """Retro 90s style ASCII loopstation display."""
    
    def __init__(self):
        self.last_state = None
        self.frame_count = 0
        # Hide cursor and clear screen on init
        print("\033[?25l", end="")  # Hide cursor
        print("\033[2J", end="")    # Clear screen
        self._draw_frame()
    
    def _draw_frame(self):
        """Draw the static device frame (only once)."""
        print("\033[H", end="")  # Move to top
        
        # Retro 90s device frame with double-line box drawing
        frame = """
\033[1;36m╔══════════════════════════════════════════════════════════╗
║\033[1;33m  ░▒▓█ \033[1;37mLOOP STATION 2000\033[1;33m █▓▒░  \033[1;32m[DIGITAL SAMPLER]\033[1;36m        ║
╠══════════════════════════════════════════════════════════╣\033[0m
║                                                          ║
║  \033[1;35m┌─────────────────────────────────────────────────────┐\033[0m  ║
║  \033[1;35m│\033[0m                                                     \033[1;35m│\033[0m  ║
║  \033[1;35m│\033[0m   MODE:          BPM:          STATUS:             \033[1;35m│\033[0m  ║
║  \033[1;35m│\033[0m                                                     \033[1;35m│\033[0m  ║
║  \033[1;35m└─────────────────────────────────────────────────────┘\033[0m  ║
║                                                          ║
║  \033[1;33m╔═══════════════════════════════════════════════════╗\033[0m  ║
║  \033[1;33m║\033[0m  POSITION                                         \033[1;33m║\033[0m  ║
║  \033[1;33m║\033[0m  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ \033[1;33m║\033[0m  ║
║  \033[1;33m╚═══════════════════════════════════════════════════╝\033[0m  ║
║                                                          ║
║  \033[1;32mTRACKS:\033[0m                                              ║
║  [0] [1] [2] [3] [4] [5] [6] [7] [8] [9]                ║
║                                                          ║
\033[1;36m╠══════════════════════════════════════════════════════════╣
║\033[0;36m  [R]ec [P]lay [O]vrdub [U]ndo [E]rase  \033[1;31m[X]EXIT\033[1;36m         ║
╚══════════════════════════════════════════════════════════╝\033[0m
"""
        print(frame)
    
    def update(self, state):
        """Update dynamic parts of the display."""
        if state is None:
            # Show waiting state
            print("\033[7;8H", end="")  # Position for mode
            print("\033[1;33m   ░░ WAITING FOR SIGNAL ░░   \033[0m", end="")
            sys.stdout.flush()
            return
        
        self.frame_count += 1
        
        # Update MODE (line 7, col 10)
        mode = state.get('mode', 'free').upper()
        print("\033[7;10H", end="")
        if mode == "MEASURE":
            print(f"\033[1;32m{mode:8}\033[0m", end="")
        else:
            print(f"\033[1;34m{mode:8}\033[0m", end="")
        
        # Update BPM (line 7, col 24)
        bpm = state.get('bpm', 120)
        print("\033[7;24H", end="")
        print(f"\033[1;37m{bpm:6.1f}\033[0m", end="")
        
        # Update STATUS (line 7, col 40)
        print("\033[7;40H", end="")
        if state.get('recording'):
            # Blinking REC
            if self.frame_count % 4 < 2:
                print("\033[1;31m● RECORDING \033[0m", end="")
            else:
                print("\033[0;31m○ RECORDING \033[0m", end="")
        elif state.get('overdubbing'):
            if self.frame_count % 4 < 2:
                print("\033[1;33m● OVERDUB   \033[0m", end="")
            else:
                print("\033[0;33m○ OVERDUB   \033[0m", end="")
        elif state.get('playing'):
            print("\033[1;32m▶ PLAYING   \033[0m", end="")
        elif state.get('loopExists'):
            print("\033[1;37m■ STOPPED   \033[0m", end="")
        else:
            print("\033[0;37m  EMPTY     \033[0m", end="")
        
        # Update POSITION BAR (line 13, col 6)
        pos = state.get('pos', 0)
        led_count = state.get('ledCount', 16)
        bar_width = 47
        
        print("\033[13;6H", end="")
        if state.get('loopExists'):
            filled = int((pos / max(led_count, 1)) * bar_width)
            
            # Determine bar color based on state
            if state.get('recording'):
                bar_color = "\033[1;31m"  # Red
                empty_color = "\033[0;31m"
            elif state.get('overdubbing'):
                bar_color = "\033[1;33m"  # Yellow
                empty_color = "\033[0;33m"
            else:
                bar_color = "\033[1;32m"  # Green
                empty_color = "\033[0;32m"
            
            # VU meter style with gradient
            bar = ""
            for i in range(bar_width):
                if i < filled:
                    if i < bar_width * 0.6:
                        bar += f"{bar_color}█"
                    elif i < bar_width * 0.8:
                        bar += "\033[1;33m█"  # Yellow zone
                    else:
                        bar += "\033[1;31m█"  # Red zone
                else:
                    bar += f"{empty_color}░"
            print(f"{bar}\033[0m", end="")
        else:
            print("\033[0;36m" + "─" * bar_width + "\033[0m", end="")
        
        # Update TRACKS (line 17, col 4)
        track_states = state.get('tracks', [1])
        selected = state.get('selectedTrack', 0)
        
        print("\033[17;4H", end="")
        for i in range(10):
            if i < len(track_states):
                active = track_states[i]
                if i == selected:
                    # Selected track - inverted
                    if active:
                        print(f"\033[7;32m[{i}]\033[0m ", end="")
                    else:
                        print(f"\033[7;31m({i})\033[0m ", end="")
                else:
                    if active:
                        print(f"\033[1;32m[{i}]\033[0m ", end="")
                    else:
                        print(f"\033[0;31m[·]\033[0m ", end="")
            else:
                print(f"\033[0;30m[·]\033[0m ", end="")
        
        sys.stdout.flush()
    
    def cleanup(self):
        """Clean up terminal display."""
        print("\033[22;1H", end="")  # Move below display
        print("\033[?25h", end="")   # Show cursor
        print("\n\033[1;36m>>> LOOP STATION 2000 - POWER OFF <<<\033[0m\n")

# ============================================================
# OLED Display (SSD1306)
# ============================================================

class OLEDDisplay:
    """SSD1306 OLED display via I2C."""
    
    def __init__(self):
        self.device = None
        self.font = None
        try:
            from luma.core.interface.serial import i2c
            from luma.oled.device import ssd1306
            from PIL import ImageFont
            
            serial = i2c(port=1, address=0x3C)
            self.device = ssd1306(serial, width=128, height=64)
            
            # Try to load a better font, fall back to default
            try:
                self.font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 10)
                self.font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 12)
            except:
                self.font = ImageFont.load_default()
                self.font_large = self.font
                
            print("[OLED] Connected to SSD1306")
        except ImportError:
            print("[OLED] luma.oled not installed - run: pip install luma.oled")
            raise
        except Exception as e:
            print(f"[OLED] Failed to initialize: {e}")
            raise
    
    def update(self, state):
        """Update OLED display."""
        if self.device is None or state is None:
            return
        
        from luma.core.render import canvas
        
        with canvas(self.device) as draw:
            # Header
            mode = state.get('mode', 'free').upper()[:4]
            bpm = state.get('bpm', 120)
            draw.text((0, 0), f"LOOP {bpm:.0f}BPM {mode}", font=self.font_large, fill="white")
            
            # Status line
            y = 14
            status = ""
            if state.get('recording'):
                status = "● RECORDING"
            elif state.get('overdubbing'):
                status = "● OVERDUB"
            elif state.get('playing'):
                status = "▶ PLAYING"
            else:
                status = "■ STOPPED"
            draw.text((0, y), status, font=self.font, fill="white")
            
            # Track count
            tracks = state.get('trackCount', 1)
            draw.text((90, y), f"T:{tracks}", font=self.font, fill="white")
            
            # Track indicators (row of boxes)
            y = 28
            track_states = state.get('tracks', [1])
            for i, active in enumerate(track_states[:8]):
                x = i * 16
                if active:
                    draw.rectangle([x, y, x+12, y+10], outline="white", fill="white")
                    draw.text((x+3, y), str(i), font=self.font, fill="black")
                else:
                    draw.rectangle([x, y, x+12, y+10], outline="white", fill="black")
                    draw.text((x+3, y), str(i), font=self.font, fill="white")
            
            # Loop position bar
            y = 44
            pos = state.get('pos', 0)
            led_count = state.get('ledCount', 16)
            
            if state.get('loopExists'):
                bar_width = 124
                filled = int((pos / max(led_count, 1)) * bar_width)
                draw.rectangle([2, y, 126, y+16], outline="white")
                if filled > 0:
                    draw.rectangle([2, y, 2+filled, y+16], fill="white")
            else:
                draw.rectangle([2, y, 126, y+16], outline="white")
                draw.text((40, y+3), "NO LOOP", font=self.font, fill="white")
    
    def cleanup(self):
        """Clear display on exit."""
        if self.device:
            self.device.clear()

# ============================================================
# LED Strip (WS2812B)
# ============================================================

class LEDStrip:
    """WS2812B LED strip via GPIO (requires rpi_ws281x library)."""
    
    def __init__(self, led_count=16, gpio_pin=18, brightness=50):
        self.strip = None
        self.led_count = led_count
        try:
            from rpi_ws281x import PixelStrip, Color
            
            # LED strip configuration
            LED_FREQ_HZ = 800000
            LED_DMA = 10
            LED_INVERT = False
            LED_CHANNEL = 0
            
            self.strip = PixelStrip(led_count, gpio_pin, LED_FREQ_HZ, LED_DMA,
                                    LED_INVERT, brightness, LED_CHANNEL)
            self.strip.begin()
            self.Color = Color
            print(f"[LED] Connected to {led_count} WS2812B LEDs on GPIO {gpio_pin}")
        except ImportError:
            print("[LED] rpi_ws281x not installed - run: sudo pip install rpi_ws281x")
            raise
        except Exception as e:
            print(f"[LED] Failed to initialize: {e}")
            raise
    
    def _set_color(self, index, color):
        """Set color of single LED."""
        if self.strip and 0 <= index < self.led_count:
            self.strip.setPixelColor(index, self.Color(color[0], color[1], color[2]))
    
    def update(self, state):
        """Update LED strip based on state."""
        if self.strip is None or state is None:
            return
        
        pos = state.get('pos', 0)
        led_count = state.get('ledCount', 16)
        
        # Scale position to actual LED count
        if led_count > 0:
            led_pos = int((pos / led_count) * self.led_count)
        else:
            led_pos = 0
        
        # Determine colors based on state
        if state.get('recording'):
            current_color = COLORS['recording']
            bg_color = (30, 0, 0)  # Dim red background
        elif state.get('overdubbing'):
            current_color = COLORS['overdub']
            bg_color = (30, 20, 0)  # Dim yellow background
        elif state.get('playing'):
            current_color = COLORS['position']
            bg_color = COLORS['off']
        else:
            current_color = COLORS['off']
            bg_color = COLORS['off']
        
        # Update all LEDs
        for i in range(self.led_count):
            if i == led_pos and state.get('loopExists'):
                self._set_color(i, current_color)
            elif state.get('loopExists') and state.get('playing'):
                self._set_color(i, bg_color)
            else:
                self._set_color(i, COLORS['off'])
        
        self.strip.show()
    
    def cleanup(self):
        """Turn off all LEDs on exit."""
        if self.strip:
            for i in range(self.led_count):
                self._set_color(i, COLORS['off'])
            self.strip.show()

# ============================================================
# Main Loop
# ============================================================

def main():
    parser = argparse.ArgumentParser(description='Loopstation Display Driver')
    parser.add_argument('--terminal', action='store_true', 
                        help='Use terminal display only (no hardware)')
    parser.add_argument('--no-oled', action='store_true',
                        help='Disable OLED display')
    parser.add_argument('--no-led', action='store_true',
                        help='Disable LED strip')
    parser.add_argument('--led-count', type=int, default=16,
                        help='Number of LEDs in strip (default: 16)')
    parser.add_argument('--led-pin', type=int, default=18,
                        help='GPIO pin for LED strip (default: 18)')
    parser.add_argument('--brightness', type=int, default=50,
                        help='LED brightness 0-255 (default: 50)')
    args = parser.parse_args()
    
    displays = []
    
    # Always try terminal display
    if args.terminal:
        displays.append(TerminalDisplay())
        print("[Terminal] Display enabled")
    
    # Try OLED if not disabled and not in terminal-only mode
    if not args.terminal and not args.no_oled:
        try:
            displays.append(OLEDDisplay())
        except:
            print("[OLED] Not available, skipping")
    
    # Try LED strip if not disabled and not in terminal-only mode
    if not args.terminal and not args.no_led:
        try:
            displays.append(LEDStrip(args.led_count, args.led_pin, args.brightness))
        except:
            print("[LED] Not available, skipping")
    
    # Fall back to terminal if no hardware displays available
    if not displays:
        print("[Info] No hardware displays available, using terminal")
        displays.append(TerminalDisplay())
    
    print(f"\n[Display Driver] Running with {len(displays)} display(s)...")
    print("[Display Driver] Waiting for loopstation...")
    print("[Display Driver] Press Ctrl+C to stop\n")
    
    try:
        while True:
            state = read_state()
            for display in displays:
                display.update(state)
            time.sleep(UPDATE_INTERVAL)
    
    except KeyboardInterrupt:
        print("\n[Display Driver] Shutting down...")
    
    finally:
        for display in displays:
            display.cleanup()

if __name__ == "__main__":
    main()
