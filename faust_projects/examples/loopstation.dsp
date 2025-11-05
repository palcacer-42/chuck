// FAUST LOOP STATION - Enhanced Version
// Real-time looper with delay-based recording and playback
// Features: Multiple overdubs, metronome, individual gain controls
// ================================================================

declare name "Loop Station";
declare author "Faust Loop Station";
declare version "1.0";

import("stdfaust.lib");

// ================================================================
// PARAMETERS
// ================================================================

// Loop timing (4-beat loop)
bpm = hslider("v:[0]Master/[0]BPM", 120, 40, 300, 0.1);
beats_per_loop = 4; // Fixed 4-beat loops
loop_seconds = (60.0 / bpm) * beats_per_loop;
loop_samples = int(loop_seconds * ma.SR);
max_delay = 480000; // 10 seconds max at 48kHz

// Master controls
input_gain = vslider("v:[0]Master/[1]Input Gain[style:knob]", 0.8, 0, 1.5, 0.01) : si.smoo;
master_gain = vslider("v:[0]Master/[2]Output Gain[style:knob]", 0.7, 0, 1.5, 0.01) : si.smoo;

// Metronome
metro_enable = checkbox("v:[0]Master/[3]Metronome");
metro_vol = vslider("v:[0]Master/[4]Click Volume[style:knob]", 0.2, 0, 1, 0.01) : si.smoo;

// Loop 1 (Main) Controls
loop1_rec = button("v:[1]Loop 1 (Main)/[0]Record");
loop1_play = checkbox("v:[1]Loop 1 (Main)/[1]Play") : si.smoo;
loop1_gain = vslider("v:[1]Loop 1 (Main)/[2]Gain[style:knob]", 1.0, 0, 1.5, 0.01) : si.smoo;

// Loop 2 Controls
loop2_rec = button("v:[2]Loop 2/[0]Record");
loop2_play = checkbox("v:[2]Loop 2/[1]Play") : si.smoo;
loop2_gain = vslider("v:[2]Loop 2/[2]Gain[style:knob]", 0.8, 0, 1.5, 0.01) : si.smoo;

// Loop 3 Controls  
loop3_rec = button("v:[3]Loop 3/[0]Record");
loop3_play = checkbox("v:[3]Loop 3/[1]Play") : si.smoo;
loop3_gain = vslider("v:[3]Loop 3/[2]Gain[style:knob]", 0.8, 0, 1.5, 0.01) : si.smoo;

// Loop 4 Controls
loop4_rec = button("v:[4]Loop 4/[0]Record");
loop4_play = checkbox("v:[4]Loop 4/[1]Play") : si.smoo;
loop4_gain = vslider("v:[4]Loop 4/[2]Gain[style:knob]", 0.8, 0, 1.5, 0.01) : si.smoo;

// ================================================================
// METRONOME - Accurate beat click
// ================================================================

// Phase accumulator for precise timing
beat_freq = bpm / 60.0;
beat_phase = os.phasor(1, beat_freq);

// Generate click on beat (when phase wraps from ~1 to ~0)
click_trigger = (beat_phase < (1.0 / ma.SR * beat_freq));

// Click sound - short beep
metro_click = os.osc(1200) * en.ar(0.001, 0.03, click_trigger) * metro_vol * metro_enable;

// ================================================================
// DELAY-BASED LOOPER
// ================================================================

// Creates a looping delay line that can record and playback
// When rec is pressed: records input to delay buffer
// When play is on: plays back from delay buffer in a loop
simple_looper(input, rec_button, play_switch, gain_level) = output
with {
    // Create a circular delay buffer
    delay_line = input : de.sdelay(max_delay, 1024, loop_samples);
    
    // Feedback loop for continuous recording/overdubbing
    // When recording: input goes to delay
    // When playing: delay output loops back
    rec_gate = rec_button : si.smoo;
    play_gate = play_switch;
    
    // Mix recording and playback
    buffer_mix = (input * rec_gate) + (delay_line * play_gate * (1 - rec_gate * 0.5));
    
    // Output with gain
    output = buffer_mix * gain_level * play_gate;
};

// ================================================================
// EFFECTS - Optional processing
// ================================================================

// Simple reverb for ambience (optional)
reverb_amt = vslider("v:[5]FX/[0]Reverb[style:knob]", 0.0, 0, 1, 0.01) : si.smoo;
stereo_reverb(l, r) = l_out, r_out
with {
    l_out = l <: _, (re.mono_freeverb(0.7, 0.5, 0.5, 5000) * reverb_amt) :> _;
    r_out = r <: _, (re.mono_freeverb(0.7, 0.5, 0.5, 5000) * reverb_amt) :> _;
};

// ================================================================
// MAIN PROCESS
// ================================================================

process = input_section : loopers : mixer : effects : master_out
with {
    // Input stage
    input_section(l, r) = l * input_gain, r * input_gain;
    
    // Four independent loopers (stereo pairs)
    loopers(inL, inR) = loop1L, loop1R, loop2L, loop2R, loop3L, loop3R, loop4L, loop4R
    with {
        // Loop 1 (Main loop)
        loop1L = inL : simple_looper(loop1_rec, loop1_play, loop1_gain);
        loop1R = inR : simple_looper(loop1_rec, loop1_play, loop1_gain);
        
        // Loop 2 (Overdub 1) - can hear loop 1 while recording
        feedback_inL_2 = inL + loop1L * 0.3;
        feedback_inR_2 = inR + loop1R * 0.3;
        loop2L = feedback_inL_2 : simple_looper(loop2_rec, loop2_play, loop2_gain);
        loop2R = feedback_inR_2 : simple_looper(loop2_rec, loop2_play, loop2_gain);
        
        // Loop 3 (Overdub 2)
        feedback_inL_3 = inL + (loop1L + loop2L) * 0.3;
        feedback_inR_3 = inR + (loop1R + loop2R) * 0.3;
        loop3L = feedback_inL_3 : simple_looper(loop3_rec, loop3_play, loop3_gain);
        loop3R = feedback_inR_3 : simple_looper(loop3_rec, loop3_play, loop3_gain);
        
        // Loop 4 (Overdub 3)
        feedback_inL_4 = inL + (loop1L + loop2L + loop3L) * 0.3;
        feedback_inR_4 = inR + (loop1R + loop2R + loop3R) * 0.3;
        loop4L = feedback_inL_4 : simple_looper(loop4_rec, loop4_play, loop4_gain);
        loop4R = feedback_inR_4 : simple_looper(loop4_rec, loop4_play, loop4_gain);
    };
    
    // Mix all loops together
    mixer(l1, r1, l2, r2, l3, r3, l4, r4) = mixL, mixR
    with {
        mixL = l1 + l2 + l3 + l4;
        mixR = r1 + r2 + r3 + r4;
    };
    
    // Optional effects
    effects = stereo_reverb;
    
    // Master output with metronome
    master_out(l, r) = outL, outR
    with {
        outL = (l + metro_click) * master_gain;
        outR = (r + metro_click) * master_gain;
    };
};
