#!/usr/bin/env python3
"""
OSC Controller for Faust Loopstation
Send OSC messages to control the loopstation in real-time
"""

import argparse
from pythonosc import udp_client

# Default OSC settings (Faust default is port 5510)
OSC_IP = "127.0.0.1"
OSC_PORT = 5510

def send_osc(client, address, value):
    """Send an OSC message"""
    client.send_message(address, float(value))
    print(f"Sent: {address} = {value}")

def main():
    parser = argparse.ArgumentParser(description='Control Faust Loopstation via OSC')
    parser.add_argument('--port', type=int, default=OSC_PORT, help='OSC port (default: 5510)')
    parser.add_argument('--ip', default=OSC_IP, help='OSC IP (default: 127.0.0.1)')
    
    # Parameter arguments
    parser.add_argument('--input', type=float, help='Input gain (0-1)')
    parser.add_argument('--wet', type=float, help='Wet mix (0-1)')
    parser.add_argument('--dry', type=float, help='Dry mix (0-1)')
    parser.add_argument('--master', type=float, help='Master volume (0-1)')
    parser.add_argument('--reverb-mix', type=float, help='Reverb mix (0-1)')
    parser.add_argument('--reverb-size', type=float, help='Reverb size (0-1)')
    parser.add_argument('--reverb-damp', type=float, help='Reverb damping (0-1)')
    parser.add_argument('--delay-mix', type=float, help='Delay mix (0-1)')
    parser.add_argument('--delay-time', type=float, help='Delay time (10-2000 ms)')
    parser.add_argument('--delay-feedback', type=float, help='Delay feedback (0-0.95)')
    parser.add_argument('--distortion', type=float, help='Distortion amount (0-0.9)')
    parser.add_argument('--pan', type=float, help='Stereo pan (-1 to 1)')
    parser.add_argument('--loop-length', type=float, help='Loop length (0.5-10 seconds)')
    
    args = parser.parse_args()
    
    # Create OSC client
    client = udp_client.SimpleUDPClient(args.ip, args.port)
    
    # Send parameters that were specified
    if args.input is not None:
        send_osc(client, "/input", args.input)
    if args.wet is not None:
        send_osc(client, "/wet", args.wet)
    if args.dry is not None:
        send_osc(client, "/dry", args.dry)
    if args.master is not None:
        send_osc(client, "/master", args.master)
    if args.reverb_mix is not None:
        send_osc(client, "/reverb/mix", args.reverb_mix)
    if args.reverb_size is not None:
        send_osc(client, "/reverb/size", args.reverb_size)
    if args.reverb_damp is not None:
        send_osc(client, "/reverb/damp", args.reverb_damp)
    if args.delay_mix is not None:
        send_osc(client, "/delay/mix", args.delay_mix)
    if args.delay_time is not None:
        send_osc(client, "/delay/time", args.delay_time)
    if args.delay_feedback is not None:
        send_osc(client, "/delay/feedback", args.delay_feedback)
    if args.distortion is not None:
        send_osc(client, "/distortion", args.distortion)
    if args.pan is not None:
        send_osc(client, "/pan", args.pan)
    if args.loop_length is not None:
        send_osc(client, "/loop/length", args.loop_length)

if __name__ == "__main__":
    main()
