// Simple lowpass filter with resonance
import("stdfaust.lib");

freq = hslider("Cutoff[style:knob]", 1000, 20, 20000, 1) : si.smoo;
q = hslider("Resonance[style:knob]", 1, 0.5, 10, 0.1) : si.smoo;
gain = hslider("Gain[style:knob]", 0.5, 0, 1, 0.01) : si.smoo;

process = no.noise * gain : fi.resonlp(freq, q, 1);
