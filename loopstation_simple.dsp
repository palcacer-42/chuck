// SIMPLE FAUST LOOPSTATION - Just Effects, No Tape Loop
// Clean pass-through with effects that you can hear immediately
// ============================================================================

import("stdfaust.lib");

// ============================================================================
// PARAMETERS
// ============================================================================

// Volume controls
inputGain = hslider("h:Volume/Input", 0.8, 0, 1, 0.01);
outputGain = hslider("h:Volume/Output", 0.7, 0, 1, 0.01);

// Effects - Reverb (OFF)
reverbMix = hslider("h:Effects/v:Reverb/Mix", 0.0, 0, 1, 0.01);
reverbSize = hslider("h:Effects/v:Reverb/Room Size", 0.5, 0, 1, 0.01);

// Effects - Delay (OFF)
delayMix = hslider("h:Effects/v:Delay/Mix", 0.0, 0, 1, 0.01);
delayTime = hslider("h:Effects/v:Delay/Time (ms)", 250, 10, 1000, 1);
delayFeedback = hslider("h:Effects/v:Delay/Feedback", 0.0, 0, 0.9, 0.01);

// Effects - Distortion (OFF)
distortion = hslider("h:Effects/v:Distortion/Drive", 0.0, 0, 0.9, 0.01);

// Pan
pan = hslider("h:Mix/Pan", 0.0, -1.0, 1.0, 0.01);

// ============================================================================
// DSP
// ============================================================================

// Stereo panner
panner(p) = _ <: *(cos(a)), *(sin(a))
with {
    a = (p + 1.0) * 0.5 * ma.PI / 2.0;
};

// Soft clipping
clip(amt) = _ : atan : *(1.0 / atan(1.0 + amt * 10.0));

// Reverb
reverb(mix, size) = _ <: *(1.0 - mix), (re.mono_freeverb(0.5, size, 0) : *(mix)) :> _;

// Delay with feedback
delay_effect(mix, time_ms, fb) = _ : (+ ~ (@(samples) : *(fb))) <: *(1.0 - mix), *(mix) :> _
with {
    samples = time_ms * 0.001 * ma.SR : int;
};

// Effects chain
fx = clip(distortion) : reverb(reverbMix, reverbSize) : delay_effect(delayMix, delayTime, delayFeedback);

// ============================================================================
// MAIN PROCESS - Simple Input -> FX -> Output
// ============================================================================

process = _ : *(inputGain) : fx : *(outputGain) : panner(pan);
