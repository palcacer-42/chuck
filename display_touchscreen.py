#!/usr/bin/env python3
"""
Loopstation Touchscreen Display
Designed for 4-inch Raspberry Pi touchscreen (480x320 or 800x480)
Retro 90s digital sampler aesthetic

Usage:
    python3 display_touchscreen.py              # Fullscreen on Pi
    python3 display_touchscreen.py --windowed   # Windowed for testing
"""

import json
import time
import argparse
import os
import sys
import math

# ============================================================
# Configuration
# ============================================================

STATE_FILE = "/tmp/loopstation_state.json"
UPDATE_INTERVAL = 50  # milliseconds

# Screen sizes (auto-detect or override)
SCREEN_480x320 = (480, 320)
SCREEN_800x480 = (800, 480)

# Retro 90s color scheme
COLORS = {
    'bg':           (10, 15, 25),       # Dark blue-black
    'frame':        (0, 180, 180),      # Cyan
    'frame_dark':   (0, 80, 80),        # Dark cyan
    'text':         (0, 255, 200),      # Bright cyan
    'text_dim':     (0, 120, 100),      # Dim cyan
    'recording':    (255, 50, 50),      # Red
    'overdub':      (255, 180, 0),      # Orange/Yellow
    'playing':      (0, 255, 100),      # Green
    'stopped':      (100, 100, 100),    # Gray
    'bar_empty':    (30, 40, 50),       # Dark gray
    'track_on':     (0, 200, 100),      # Green
    'track_off':    (80, 30, 30),       # Dark red
    'track_sel':    (255, 255, 0),      # Yellow highlight
    'vu_green':     (0, 255, 0),
    'vu_yellow':    (255, 255, 0),
    'vu_red':       (255, 0, 0),
    'lcd_bg':       (20, 40, 30),       # LCD green-ish background
    'lcd_text':     (150, 255, 150),    # LCD text
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
# Touchscreen GUI Display
# ============================================================

class TouchscreenDisplay:
    """Retro 90s style graphical display for RPi touchscreen."""
    
    def __init__(self, width=480, height=320, fullscreen=True):
        import pygame
        self.pygame = pygame
        
        pygame.init()
        pygame.mouse.set_visible(not fullscreen)
        
        flags = pygame.FULLSCREEN if fullscreen else 0
        self.screen = pygame.display.set_mode((width, height), flags)
        pygame.display.set_caption("LOOP STATION 2000")
        
        self.width = width
        self.height = height
        self.clock = pygame.time.Clock()
        self.frame_count = 0
        
        # Load fonts
        pygame.font.init()
        try:
            # Try system fonts first
            self.font_large = pygame.font.Font("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 
                                               int(height * 0.08))
            self.font_medium = pygame.font.Font("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 
                                                int(height * 0.05))
            self.font_small = pygame.font.Font("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 
                                               int(height * 0.04))
        except:
            # Fallback to default
            self.font_large = pygame.font.Font(None, int(height * 0.1))
            self.font_medium = pygame.font.Font(None, int(height * 0.06))
            self.font_small = pygame.font.Font(None, int(height * 0.05))
        
        self.last_state = None
    
    def _draw_frame(self):
        """Draw the device frame."""
        pygame = self.pygame
        w, h = self.width, self.height
        
        # Background
        self.screen.fill(COLORS['bg'])
        
        # Outer frame with beveled edge effect
        pygame.draw.rect(self.screen, COLORS['frame'], (0, 0, w, h), 3)
        pygame.draw.rect(self.screen, COLORS['frame_dark'], (3, 3, w-6, h-6), 2)
        
        # Title bar
        title_h = int(h * 0.12)
        pygame.draw.rect(self.screen, COLORS['frame'], (0, 0, w, title_h))
        pygame.draw.rect(self.screen, COLORS['frame_dark'], (0, title_h-2, w, 2))
        
        # Title text
        title = self.font_large.render("░▒▓ LOOP STATION 2000 ▓▒░", True, COLORS['bg'])
        title_rect = title.get_rect(center=(w//2, title_h//2))
        self.screen.blit(title, title_rect)
    
    def _draw_lcd_panel(self, x, y, w, h, label, value, color=None):
        """Draw an LCD-style info panel."""
        pygame = self.pygame
        
        # Panel background with inset effect
        pygame.draw.rect(self.screen, COLORS['lcd_bg'], (x, y, w, h))
        pygame.draw.rect(self.screen, COLORS['frame_dark'], (x, y, w, h), 1)
        
        # Label
        label_surf = self.font_small.render(label, True, COLORS['text_dim'])
        self.screen.blit(label_surf, (x + 5, y + 2))
        
        # Value
        value_color = color if color else COLORS['lcd_text']
        value_surf = self.font_medium.render(str(value), True, value_color)
        value_rect = value_surf.get_rect(center=(x + w//2, y + h//2 + 5))
        self.screen.blit(value_surf, value_rect)
    
    def _draw_vu_meter(self, x, y, w, h, position, max_pos, state):
        """Draw VU-meter style progress bar."""
        pygame = self.pygame
        
        # Background
        pygame.draw.rect(self.screen, COLORS['bar_empty'], (x, y, w, h))
        pygame.draw.rect(self.screen, COLORS['frame_dark'], (x, y, w, h), 1)
        
        if max_pos <= 0:
            return
        
        # Calculate fill
        fill_width = int((position / max_pos) * w)
        
        # Draw segments with gradient effect
        segment_w = max(2, w // 30)
        for i in range(0, fill_width, segment_w + 1):
            seg_x = x + i
            
            # Color based on position (green -> yellow -> red)
            ratio = i / w
            if ratio < 0.6:
                color = COLORS['vu_green']
            elif ratio < 0.8:
                color = COLORS['vu_yellow']
            else:
                color = COLORS['vu_red']
            
            # Override with state color
            if state.get('recording'):
                color = COLORS['recording']
            elif state.get('overdubbing'):
                color = COLORS['overdub']
            
            pygame.draw.rect(self.screen, color, (seg_x, y+2, segment_w, h-4))
        
        # Position marker
        marker_x = x + fill_width
        pygame.draw.rect(self.screen, (255, 255, 255), (marker_x-1, y, 3, h))
    
    def _draw_track_buttons(self, x, y, w, h, tracks, selected):
        """Draw track status buttons."""
        pygame = self.pygame
        
        num_tracks = min(len(tracks), 10)
        if num_tracks == 0:
            return
        
        btn_w = w // 10 - 4
        btn_h = h - 6
        
        for i in range(10):
            btn_x = x + i * (btn_w + 4)
            btn_y = y + 3
            
            if i < num_tracks:
                active = tracks[i]
                is_selected = (i == selected)
                
                # Button color
                if active:
                    bg_color = COLORS['track_on']
                else:
                    bg_color = COLORS['track_off']
                
                # Draw button
                pygame.draw.rect(self.screen, bg_color, (btn_x, btn_y, btn_w, btn_h))
                
                # Selection highlight
                if is_selected:
                    pygame.draw.rect(self.screen, COLORS['track_sel'], 
                                   (btn_x, btn_y, btn_w, btn_h), 2)
                else:
                    pygame.draw.rect(self.screen, COLORS['frame_dark'], 
                                   (btn_x, btn_y, btn_w, btn_h), 1)
                
                # Track number
                num_surf = self.font_small.render(str(i), True, 
                    COLORS['bg'] if active else COLORS['text_dim'])
                num_rect = num_surf.get_rect(center=(btn_x + btn_w//2, btn_y + btn_h//2))
                self.screen.blit(num_surf, num_rect)
            else:
                # Empty slot
                pygame.draw.rect(self.screen, (20, 20, 20), (btn_x, btn_y, btn_w, btn_h))
                pygame.draw.rect(self.screen, COLORS['frame_dark'], (btn_x, btn_y, btn_w, btn_h), 1)
    
    def _draw_status_led(self, x, y, size, color, blink=False):
        """Draw a status LED indicator."""
        pygame = self.pygame
        
        # LED off state
        if blink and (self.frame_count // 5) % 2:
            color = tuple(c // 4 for c in color)
        
        # LED glow effect
        glow_color = tuple(min(255, c + 50) for c in color)
        pygame.draw.circle(self.screen, glow_color, (x, y), size)
        pygame.draw.circle(self.screen, color, (x, y), size - 2)
        
        # Highlight
        highlight_color = tuple(min(255, c + 100) for c in color)
        pygame.draw.circle(self.screen, highlight_color, (x - size//4, y - size//4), size//4)
    
    def update(self, state):
        """Update the display."""
        pygame = self.pygame
        
        # Handle events
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE or event.key == pygame.K_q:
                    return False
        
        self.frame_count += 1
        w, h = self.width, self.height
        
        # Draw static frame
        self._draw_frame()
        
        # Calculate layout
        title_h = int(h * 0.12)
        padding = int(w * 0.02)
        
        if state is None:
            # Waiting state
            waiting = self.font_medium.render("░░ WAITING FOR SIGNAL ░░", True, COLORS['text'])
            wait_rect = waiting.get_rect(center=(w//2, h//2))
            self.screen.blit(waiting, wait_rect)
            pygame.display.flip()
            return True
        
        # Info panels row
        panel_y = title_h + padding
        panel_h = int(h * 0.15)
        panel_w = (w - padding * 4) // 3
        
        # Mode panel
        mode = state.get('mode', 'free').upper()
        mode_color = COLORS['playing'] if mode == "MEASURE" else COLORS['text']
        self._draw_lcd_panel(padding, panel_y, panel_w, panel_h, "MODE", mode, mode_color)
        
        # BPM panel
        bpm = state.get('bpm', 120)
        self._draw_lcd_panel(padding*2 + panel_w, panel_y, panel_w, panel_h, 
                            "BPM", f"{bpm:.1f}", COLORS['lcd_text'])
        
        # Status panel with LED
        status_x = padding*3 + panel_w*2
        pygame.draw.rect(self.screen, COLORS['lcd_bg'], (status_x, panel_y, panel_w, panel_h))
        pygame.draw.rect(self.screen, COLORS['frame_dark'], (status_x, panel_y, panel_w, panel_h), 1)
        
        label_surf = self.font_small.render("STATUS", True, COLORS['text_dim'])
        self.screen.blit(label_surf, (status_x + 5, panel_y + 2))
        
        # Status text and LED
        if state.get('recording'):
            status_text = "REC"
            led_color = COLORS['recording']
            blink = True
        elif state.get('overdubbing'):
            status_text = "OVD"
            led_color = COLORS['overdub']
            blink = True
        elif state.get('playing'):
            status_text = "PLAY"
            led_color = COLORS['playing']
            blink = False
        elif state.get('loopExists'):
            status_text = "STOP"
            led_color = COLORS['stopped']
            blink = False
        else:
            status_text = "EMPTY"
            led_color = COLORS['text_dim']
            blink = False
        
        self._draw_status_led(status_x + panel_w - 25, panel_y + panel_h//2, 12, led_color, blink)
        
        status_surf = self.font_medium.render(status_text, True, led_color)
        status_rect = status_surf.get_rect(center=(status_x + panel_w//2 - 10, panel_y + panel_h//2 + 5))
        self.screen.blit(status_surf, status_rect)
        
        # VU Meter / Position bar
        vu_y = panel_y + panel_h + padding
        vu_h = int(h * 0.15)
        vu_label = self.font_small.render("POSITION", True, COLORS['text'])
        self.screen.blit(vu_label, (padding, vu_y - 15))
        
        if state.get('loopExists'):
            pos = state.get('pos', 0)
            led_count = state.get('ledCount', 16)
            self._draw_vu_meter(padding, vu_y, w - padding*2, vu_h, pos, led_count, state)
        else:
            pygame.draw.rect(self.screen, COLORS['bar_empty'], (padding, vu_y, w - padding*2, vu_h))
            pygame.draw.rect(self.screen, COLORS['frame_dark'], (padding, vu_y, w - padding*2, vu_h), 1)
            no_loop = self.font_medium.render("-- NO LOOP --", True, COLORS['text_dim'])
            no_loop_rect = no_loop.get_rect(center=(w//2, vu_y + vu_h//2))
            self.screen.blit(no_loop, no_loop_rect)
        
        # Tracks row
        tracks_y = vu_y + vu_h + padding
        tracks_h = int(h * 0.12)
        tracks_label = self.font_small.render(f"TRACKS ({state.get('trackCount', 1)})", True, COLORS['text'])
        self.screen.blit(tracks_label, (padding, tracks_y - 15))
        
        track_states = state.get('tracks', [1])
        selected = state.get('selectedTrack', 0)
        self._draw_track_buttons(padding, tracks_y, w - padding*2, tracks_h, track_states, selected)
        
        # Controls hint at bottom
        controls_y = h - int(h * 0.08)
        controls = "[R]ec  [P]lay  [O]vdub  [U]ndo  [E]rase  [X]Exit"
        controls_surf = self.font_small.render(controls, True, COLORS['text_dim'])
        controls_rect = controls_surf.get_rect(center=(w//2, controls_y))
        self.screen.blit(controls_surf, controls_rect)
        
        pygame.display.flip()
        return True
    
    def cleanup(self):
        """Clean up display."""
        self.pygame.quit()

# ============================================================
# Main
# ============================================================

def main():
    parser = argparse.ArgumentParser(description='Loopstation Touchscreen Display')
    parser.add_argument('--windowed', action='store_true', 
                        help='Run in windowed mode (for testing)')
    parser.add_argument('--width', type=int, default=480,
                        help='Screen width (default: 480)')
    parser.add_argument('--height', type=int, default=320,
                        help='Screen height (default: 320)')
    args = parser.parse_args()
    
    try:
        import pygame
    except ImportError:
        print("ERROR: pygame not installed. Run: pip install pygame")
        sys.exit(1)
    
    print("[Display] LOOP STATION 2000 - Touchscreen Edition")
    print(f"[Display] Resolution: {args.width}x{args.height}")
    print("[Display] Press Q or ESC to exit")
    
    display = TouchscreenDisplay(
        width=args.width, 
        height=args.height, 
        fullscreen=not args.windowed
    )
    
    try:
        running = True
        while running:
            state = read_state()
            running = display.update(state)
            display.clock.tick(1000 // UPDATE_INTERVAL)
    
    except KeyboardInterrupt:
        print("\n[Display] Shutting down...")
    
    finally:
        display.cleanup()

if __name__ == "__main__":
    main()
