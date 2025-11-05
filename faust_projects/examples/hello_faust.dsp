// Simple sine wave oscillator
// Usage: faust2caqt hello_faust.dsp && ./hello_faust

import("stdfaust.lib");

freq = hslider("Frequency", 440, 20, 2000, 1);
gain = hslider("Gain", 0.5, 0, 1, 0.01) : si.smoo;

process = os.osc(freq) * gain;
