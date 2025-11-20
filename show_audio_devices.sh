#!/bin/bash
# Extract audio device information

INPUT=$(chuck --probe 2>&1 | grep -B6 "default input = YES" | grep "device name" | sed 's/.*device name = "\(.*\)"/\1/')
OUTPUT=$(chuck --probe 2>&1 | grep -B6 "default output = YES" | grep "device name" | sed 's/.*device name = "\(.*\)"/\1/')

echo "Input:  $INPUT"
echo "Output: $OUTPUT"
