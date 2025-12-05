// LOOP STATION V2 – "THE ULTIMATE"
// ======================================================
// Features:
// - Class-based Track system (Unlimited tracks theoretically)
// - Creative Effects: Reverse, Pitch Shift, Retrigger
// - Master Reverb & Input Monitoring
// - Session Recording to Disk
// - Improved Metronome
// - HID & Keyboard Control

// ------------------------------------------------------
// GLOBAL AUDIO GRAPH
// ------------------------------------------------------
Gain master => dac;
Gain inputBus => NRev reverb => master;
adc => inputBus; // Input monitoring path

// Session Recorder
WvOut2 wout => blackhole;
master => wout;

// Master Effects Settings
0.1 => reverb.mix;
0.8 => master.gain;
0 => int inputMonitorOn;
inputBus.gain(0.0); // Start with monitoring OFF

// Global Timing
120.0 => float bpm;
(60.0 / bpm) :: second => dur beatDur;
4 => int beatsPerLoop;
dur loopLength;

// ------------------------------------------------------
// CLASS: METRONOME
// ------------------------------------------------------
class Metronome
{
    Impulse i => BiQuad f => Gain g => master;
    .99 => f.prad;
    .05 => f.gain;
    1 => g.gain;
    
    fun void tick(int strong)
    {
        if (strong) 
        {
            2000 => f.pfreq;
            1.0 => i.next;
        }
        else 
        {
            1000 => f.pfreq;
            0.7 => i.next;
        }
    }
}
Metronome click;

// ------------------------------------------------------
// CLASS: LOOP TRACK
// ------------------------------------------------------
class LoopTrack
{
    LiSa sample => Pan2 p => reverb;
    
    // State
    0 => int isRecording;
    0 => int isPlaying;
    0 => int hasAudio;
    0 => int isReverse;
    1.0 => float rate;
    
    // Setup
    sample.gain(1.0);
    sample.feedback(0.0);
    sample.loop(1);
    
    fun void setup(dur maxDur)
    {
        sample.duration(maxDur);
    }

    fun void patchInput(UGen src)
    {
        src => sample;
    }
    
    fun void record(dur len)
    {
        1 => isRecording;
        sample.record(1);
        // If length is known (Measure mode), we could schedule stop
        // But for flexibility, we handle stop manually or via global sync
    }
    
    fun void stopRecord(dur len)
    {
        sample.record(0);
        0 => isRecording;
        1 => hasAudio;
        
        // Set loop points
        sample.loopStart(0::ms);
        sample.loopEnd(len);
        sample.loopEndRec(len - 10::ms); // Crossfade
        
        // Auto-play
        play();
    }
    
    fun void play()
    {
        if (!hasAudio) return;
        1 => isPlaying;
        sample.play(1);
        sample.rampUp(10::ms);
    }
    
    fun void stop()
    {
        0 => isPlaying;
        sample.rampDown(10::ms);
        // Wait for ramp before fully stopping play head? 
        // For simplicity in this realtime context, we just ramp.
    }
    
    fun void toggleReverse()
    {
        if (isReverse)
        {
            0 => isReverse;
            1.0 => rate;
        }
        else
        {
            1 => isReverse;
            -1.0 => rate;
        }
        sample.rate(rate);
    }
    
    fun void setRate(float newRate)
    {
        newRate => rate;
        if (isReverse) -1.0 * rate => sample.rate;
        else rate => sample.rate;
    }
    
    fun void retrigger()
    {
        if (isPlaying)
        {
            if (isReverse) sample.playPos(sample.loopEnd());
            else sample.playPos(sample.loopStart());
        }
    }
    
    fun void clear()
    {
        stop();
        sample.record(0);
        0 => hasAudio;
        0 => isReverse;
        1.0 => rate;
        sample.rate(1.0);
    }
}

// ------------------------------------------------------
// STATE MANAGEMENT
// ------------------------------------------------------
LoopTrack tracks[8]; // 8 Tracks total
0 => int activeTrack; // Currently selected track for editing
0 => int isRecordingMaster; // Are we recording the first loop?
time masterRecStart; // Track when master recording started
0 => int masterLoopExists;
0 => int isRecordingSession; // Track session recording state
"" => string statusMessage; // Global status message

// Initialize tracks
for (0 => int i; i < 8; i++)
{
    tracks[i].setup(60::second);
    tracks[i].patchInput(adc);
}

// ------------------------------------------------------
// UI & DISPLAY
// ------------------------------------------------------
fun void updateDisplay()
{
    // Move cursor to top-left and clear screen
    // \033[H = Home, \033[2J = Clear Screen
    chout <= "\033[H\033[2J";
    
    chout <= "=== LOOP STATION V2 ===\n";
    chout <= "BPM: " <= bpm <= " | Beats: " <= beatsPerLoop <= "\n";
    
    if (inputMonitorOn) chout <= "[MONITOR: ON] "; else chout <= "[MONITOR: OFF] ";
    if (reverb.mix() > 0.01) chout <= "[REVERB: ON] "; else chout <= "[REVERB: OFF] ";
    chout <= "\n";
    chout <= "STATUS: " <= statusMessage <= "\n\n";
    
    chout <= "TRACKS:\n";
    for (0 => int i; i < 8; i++)
    {
        if (i == activeTrack) chout <= " > "; else chout <= "   ";
        
        chout <= "[" <= (i+1) <= "] ";
        
        if (tracks[i].isRecording) chout <= "● REC ";
        else if (tracks[i].isPlaying) chout <= "▶ PLAY";
        else if (tracks[i].hasAudio) chout <= "◼ STOP";
        else chout <= "_ EMPTY";
        
        if (tracks[i].isReverse) chout <= " [REV]";
        if (tracks[i].rate != 1.0) chout <= " [" <= tracks[i].rate <= "x]";
        
        chout <= "\n";
    }
    
    chout <= "\nCONTROLS:\n";
    chout <= "[r] Rec/Dub | [p] Play/Stop | [e] Erase All\n";
    chout <= "[1-8] Select Track | [z] Reverse | [m] Monitor | [v] Reverb\n";
    chout <= "[[] Rate Down | []] Rate Up | [SPACE] Retrigger\n";
    chout <= "[S] Save Session | [q] Quit\n";
    
    chout.flush();
}

// ------------------------------------------------------
// SYNC & EVENTS
// ------------------------------------------------------
Event loopStart;

// ------------------------------------------------------
// CONTROL LOGIC
// ------------------------------------------------------
fun void handleInput()
{
    KBHit kb;
    while (true)
    {
        kb => now;
        while (kb.more())
        {
            kb.getchar() => int k;
            
            // TRACK SELECTION
            if (k >= '1' && k <= '8')
            {
                k - '1' => activeTrack;
            }
            
            // RECORDING
            else if (k == 'r')
            {
                if (!masterLoopExists)
                {
                    // Start Master Loop Recording
                    if (!isRecordingMaster)
                    {
                        1 => isRecordingMaster;
                        now => masterRecStart;
                        tracks[0].record(60::second); // Max buffer
                        "Recording Master Loop..." => statusMessage;
                    }
                    else
                    {
                        // Stop Master Loop Recording
                        0 => isRecordingMaster;
                        1 => masterLoopExists;
                        
                        // Calculate actual loop length from recording
                        now - masterRecStart => loopLength;
                        
                        // Update BPM estimate (assuming 4 beats) - Optional but nice
                        // (60.0 / (loopLength/second / 4.0)) => bpm;
                        
                        tracks[0].stopRecord(loopLength);
                        "Master Loop Recorded: " + (loopLength/second) + "s" => statusMessage;
                    }
                }
                else
                {
                    // Overdub / Record on active track
                    if (tracks[activeTrack].isRecording)
                    {
                        tracks[activeTrack].stopRecord(loopLength);
                    }
                    else
                    {
                        // QUANTIZED RECORDING START
                        // Wait for next loop start to ensure sync
                        spork ~ syncRecord(activeTrack);
                    }
                }
            }
            
            // PLAY / STOP
            else if (k == 'p')
            {
                if (tracks[activeTrack].isPlaying) tracks[activeTrack].stop();
                else tracks[activeTrack].play();
            }
            
            // EFFECTS
            else if (k == 'z') tracks[activeTrack].toggleReverse();
            else if (k == ' ') tracks[activeTrack].retrigger();
            else if (k == '[') tracks[activeTrack].setRate(tracks[activeTrack].rate * 0.5);
            else if (k == ']') tracks[activeTrack].setRate(tracks[activeTrack].rate * 2.0);
            
            // GLOBAL
            else if (k == 'm') 
            {
                !inputMonitorOn => inputMonitorOn;
                if (inputMonitorOn) inputBus.gain(1.0); else inputBus.gain(0.0);
            }
            else if (k == 'v')
            {
                if (reverb.mix() > 0.01) reverb.mix(0.0); else reverb.mix(0.1);
            }
            else if (k == 'e')
            {
                for (0 => int i; i < 8; i++) tracks[i].clear();
                0 => masterLoopExists;
            }
            
            // SESSION RECORDING
            else if (k == 'S')
            {
                if (isRecordingSession == 0)
                {
                    "session.wav" => wout.wavFilename;
                    1 => isRecordingSession;
                    "Recording session to session.wav..." => statusMessage;
                }
                else
                {
                    wout.closeFile();
                    "" => wout.wavFilename;
                    0 => isRecordingSession;
                    "Session saved!" => statusMessage;
                }
            }
            
            updateDisplay();
        }
    }
}

// Helper to sync recording start
fun void syncRecord(int trackIdx)
{
    "Waiting for loop start..." => statusMessage;
    updateDisplay();
    loopStart => now;
    "Recording..." => statusMessage;
    updateDisplay();
    tracks[trackIdx].record(loopLength);
    "Recorded!" => statusMessage;
    updateDisplay();
}

// ------------------------------------------------------
// MAIN LOOP
// ------------------------------------------------------
updateDisplay();
spork ~ handleInput();

// Metronome & Sync Loop
while (true)
{
    if (masterLoopExists)
    {
        // Broadcast loop start
        loopStart.broadcast();
        click.tick(1);
        
        // Progress Bar Animation
        now => time loopStartTime;
        while (now < loopStartTime + loopLength)
        {
            // Update UI every 100ms
            100::ms => now;
            
            // Calculate progress 0.0 - 1.0
            (now - loopStartTime) / loopLength => float progress;
            
            // Visual Progress Bar in Status
            "PLAYING [";
            for (0 => int i; i < 20; i++)
            {
                if (i < (progress * 20)) "#" +=> statusMessage;
                else "-" +=> statusMessage;
            }
            "]" +=> statusMessage;
            
            updateDisplay();
        }
    }
    else if (isRecordingMaster)
    {
        // Metronome during master recording
        click.tick(1);
        beatDur => now;
        // Blink recording status
        "RECORDING... " + ((now - masterRecStart)/second) + "s" => statusMessage;
        updateDisplay();
    }
    else
    {
        // Idle state
        100::ms => now;
    }
}
