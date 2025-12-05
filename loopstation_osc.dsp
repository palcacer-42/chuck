// LOOPSTATION IN FAUST - OSC Controllable Version
// Real-time parameter control via OSC messages
// ============================================================================

declare options "[osc:on]";  // Enable OSC control

import("stdfaust.lib");

// ============================================================================
// PARAMETERS - All OSC controllable
// ============================================================================

// Volume controls
inputGain = hslider("v:Volume/Input[osc:/input 0 1]", 0.8, 0, 1, 0.01);
wetGain = hslider("v:Volume/Wet[osc:/wet 0 1]", 0.9, 0, 1, 0.01);
dryGain = hslider("v:Volume/Dry[osc:/dry 0 1]", 0.5, 0, 1, 0.01);
masterGain = hslider("v:Volume/Master[osc:/master 0 1]", 0.7, 0, 1, 0.01);

// Effects - Reverb
reverbMix = hslider("v:Reverb/Mix[osc:/reverb/mix 0 1]", 0.0, 0, 1, 0.01);
reverbSize = hslider("v:Reverb/Room Size[osc:/reverb/size 0 1]", 0.5, 0, 1, 0.01);
reverbDamp = hslider("v:Reverb/Damping[osc:/reverb/damp 0 1]", 0.5, 0, 1, 0.01);

// Effects - Delay
delayMix = hslider("v:Delay/Mix[osc:/delay/mix 0 1]", 0.0, 0, 1, 0.01);
delayTime = hslider("v:Delay/Time (ms)[osc:/delay/time 10 2000]", 250, 10, 2000, 1);
delayFeedback = hslider("v:Delay/Feedback[osc:/delay/feedback 0 0.95]", 0.3, 0, 0.95, 0.01);

// Effects - Distortion
distortionAmount = hslider("v:Distortion/Drive[osc:/distortion 0 0.9]", 0.0, 0, 0.9, 0.01);

// Pan and loop controls
mainPan = hslider("v:Mix/Pan[osc:/pan -1 1]", 0.0, -1.0, 1.0, 0.01);
loopDelayTime = hslider("v:Loop/Loop Length (s)[osc:/loop/length 0.5 10]", 4.0, 0.5, 10.0, 0.1);

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

// ============================================================================
// TAPE LOOP SYSTEM
// ============================================================================

// Creates a feedback loop that acts like a tape loop
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
// MAIN PROCESS
// ============================================================================

process = _ : *(inputGain) 
    <: (tapeLoop(loopDelayTime) : *(wetGain) : effectsChain), 
       (*(dryGain))
    :> _ 
    : *(masterGain)
    : panner(mainPan);
