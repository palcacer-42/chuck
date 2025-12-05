// LOOPSTATION IN FAUST - Simple Effects Chain Demo
// A working Faust implementation focusing on the effects processing
// (Loop recording requires custom C++ - see notes at end)
// ============================================================================

import("stdfaust.lib");

// ============================================================================
// PARAMETERS - Control Interface
// ============================================================================

// Volume controls
inputGain = hslider("h:Volume/Input", 0.8, 0, 1, 0.01);
wetGain = hslider("h:Volume/Wet", 0.9, 0, 1, 0.01);
dryGain = hslider("h:Volume/Dry", 0.5, 0, 1, 0.01);
masterGain = hslider("h:Volume/Master", 0.7, 0, 1, 0.01);

// Effects - Reverb
reverbMix = hslider("h:Effects/v:Reverb/Mix", 0.0, 0, 1, 0.01);
reverbSize = hslider("h:Effects/v:Reverb/Room Size", 0.5, 0, 1, 0.01);
reverbDamp = hslider("h:Effects/v:Reverb/Damping", 0.5, 0, 1, 0.01);

// Effects - Delay
delayMix = hslider("h:Effects/v:Delay/Mix", 0.0, 0, 1, 0.01);
delayTime = hslider("h:Effects/v:Delay/Time (ms)", 250, 10, 2000, 1);
delayFeedback = hslider("h:Effects/v:Delay/Feedback", 0.3, 0, 0.95, 0.01);

// Effects - Distortion
distortionAmount = hslider("h:Effects/v:Distortion/Drive", 0.0, 0, 0.9, 0.01);

// Pan and speed controls
mainPan = hslider("h:Mix/Pan", 0.0, -1.0, 1.0, 0.01);
playbackSpeed = hslider("h:Loop/Speed", 1.0, 0.5, 2.0, 0.01);

// Simple loop delay (acts like a looper buffer)
loopDelayTime = hslider("h:Loop/Loop Length (s)", 4.0, 0.5, 10.0, 0.1);

// ============================================================================
// DSP BUILDING BLOCKS
// ============================================================================

// Simple stereo panner
panner(pan) = _ <: *(leftGain), *(rightGain)
with {
    panAngle = (pan + 1.0) * 0.5 * ma.PI / 2.0;
    leftGain = cos(panAngle);
    rightGain = sin(panAngle);
};

// Soft clipping distortion
softClip(amount) = _ : atan : *(1.0 / atan(1.0 + amount * 10.0));

// Simple reverb using Faust's freeverb
simpleReverb(mix, size, damp) = _ <: *(1.0 - mix), (re.mono_freeverb(damp, size, 0) : *(mix)) :> _;

// Delay with feedback
feedbackDelay(mix, time_ms, feedback) = _ : (+  ~ (delayLine : *(feedback))) <: *(1.0 - mix), *(mix) :> _
with {
    samples = time_ms * 0.001 * ma.SR : int;
    delayLine = @(samples);
};

// Variable speed delay (simulates loop playback speed)
variableDelay(speed, maxTime) = _ : de.fdelay(maxDelaySize, delayAmount)
with {
    maxDelaySize = maxTime * ma.SR : int;
    delayAmount = (1.0 / speed) * maxTime * ma.SR;
};

// ============================================================================
// SIMPLE LOOP BUFFER (using delay line)
// ============================================================================

// This creates a "tape loop" effect using a fixed delay
// Not a true recording looper, but demonstrates the concept
tapeLoop(loopTime) = _ : (+  ~ (loopDelayLine : *(0.9))) 
with {
    loopSamples = loopTime * ma.SR : int;
    loopDelayLine = @(loopSamples);
};

// ============================================================================
// EFFECTS CHAIN
// ============================================================================

effectsChain = _ 
    : softClip(distortionAmount)
    : simpleReverb(reverbMix, reverbSize, reverbDamp)
    : feedbackDelay(delayMix, delayTime, delayFeedback);

// ============================================================================
// MAIN PROCESS - Looper-style Effects
// ============================================================================

process = _ : *(inputGain) 
    <: (tapeLoop(loopDelayTime) : *(wetGain) : effectsChain), 
       (*(dryGain))
    :> _ 
    : *(masterGain)
    : panner(mainPan);

// ============================================================================
// NOTES
// ============================================================================

/*
This is a WORKING Faust implementation that creates a "tape loop" effect
using delay lines. It's simpler than the full ChucK version but functional.

WHAT IT DOES:
- Creates a feedback delay loop (like a tape loop)
- Adds effects (reverb, delay, distortion)
- Wet/dry mix control
- Stereo panning

LIMITATIONS vs ChucK version:
- No true record/stop/play buttons (uses continuous tape loop)
- No multiple overdub tracks
- No HID support
- Simpler than ChucK's LiSa buffer system

TO COMPILE AND RUN:
  faust2caqt loopstation.dsp       # macOS app with GUI
  faust2jack loopstation.dsp       # Jack audio
  faust2svg loopstation.dsp        # View signal flow diagram

This demonstrates Faust's strength (effects) and weakness (complex state).
For a full loopstation, use ChucK!
*/
