#!/bin/bash
# Run ChucK with explicit dummy/null audio device
# This tells ChucK to use 0 input and 0 output channels (fake audio)
chuck --dac:0 --adc:0 --out:0 --in:0 loopstationULTIMATE.ck
