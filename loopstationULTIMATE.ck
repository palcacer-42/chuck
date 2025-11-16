// VINTAGE LOOP STATION – EXACT ○● SYMBOLS
// Seamless, audible overdub, terminal/miniAudicle, configurable beat length
// iRig BlueTurn support via HID
// ======================================================

// HID Input Setup for BlueTurn
Hid blueTurn;
HidMsg blueTurnMsg;
0 => int useHid;

// BlueTurn button codes (Page Up/Down keys)
78 => int BUTTON_1;  // Page Down - Record/Overdub
75 => int BUTTON_2;  // Page Up - Play/Stop

adc => Gain input => blackhole;
input.gain(0.8);

// Main loop using LiSa buffer
LiSa mainLoop => dac;
adc => mainLoop;
mainLoop.gain(0.9);
mainLoop.maxVoices(1);

Gain clickGain => dac;
clickGain.gain(0.5);

120.0 => float bpm;
(60.0 / bpm) :: second => dur beatDur;

dur loopLength;
0 => int isRecording;
0 => int isPlaying;
0 => int isOverdubbing;
0 => int loopExists;
5 => int beatsPerLoop;  // Configurable beat length (default 5)
20 => int ledCount;  // Will be updated based on beatsPerLoop

// Mode selection: 0 = free mode, 1 = measure mode
0 => int measureMode;

// Multiple overdubs support
LiSa overdubPlayers[10]; // Support up to 10 overdubs
0 => int overdubCount;
int overdubActive[10]; // Track which overdubs are active
1 => int mainLoopActive; // Track if main loop is active

// Initialize overdub players with LiSa buffers
for (0 => int i; i < 10; i++)
{
    adc => overdubPlayers[i] => dac;
    overdubPlayers[i].gain(0.9);
    overdubPlayers[i].maxVoices(1);
    1 => overdubActive[i]; // Start active by default
}

Event loopStart;

0 => int tapCount;
time lastTap;

// ------------------------------------------------------
// LED RING: EXACT ○ and ●
// ------------------------------------------------------

// --- show LED ring in console ---
fun void showLED(int pos)
{
    "" => string leds;
    for (0 => int i; i < ledCount; i++)
    {
        if (i == pos) leds + "●" => leds;
        else leds + "○" => leds;
        
        // Add spacing every beat (4 subdivisions per beat) for readability
        if ((i + 1) % 4 == 0 && i < ledCount - 1) leds + " " => leds;
    }
    
    // Use chout with carriage return for static display (overwrites same line)
    chout <= "\r" <= leds <= " ";
    chout.flush();
}

// ------------------------------------------------------
// Tap Tempo
// ------------------------------------------------------
fun void tapTempo()
{
    now => time cur;
    if (tapCount > 0)
    {
        (cur - lastTap) => dur iv;
        (60.0 / (iv/second)) => float newBPM;
        if (newBPM > 10 && newBPM < 300)

        {
            newBPM => bpm;
            (60.0 / bpm) :: second => beatDur;
            <<< "TEMPO:", bpm, "BPM" >>>;
        }
    }
    else
    {
        <<< "First tap – tap again…" >>>;
    }
    cur => lastTap;
    tapCount + 1 => tapCount;
    spork ~ resetTapCount();
}

fun void resetTapCount()
{
    2::second => now;
    0 => tapCount;
}

// ------------------------------------------------------
// Set Beat Length
// ------------------------------------------------------
fun void setBeatLength()
{
    if (isPlaying || loopExists)
    {
        <<< "Cannot change beat length while loop exists. Stop and clear first." >>>;
        return;
    }
    
    <<< "\nEnter number of beats (1-9, or press 1 then 0-6 for 10-16), then press Enter: " >>>;
    
    "" => string input;
    KBHit kb2;
    1 => int listening;
    
    while (listening)
    {
        kb2 => now;
        while (kb2.more())
        {
            kb2.getchar() => int k;
            
            // Enter key (newline or return)
            if (k == 10 || k == 13) // ASCII newline or carriage return
            {
                if (input.length() > 0)
                {
                    Std.atoi(input) => int newBeats;
                    if (newBeats >= 1 && newBeats <= 16)
                    {
                        newBeats => beatsPerLoop;
                        beatsPerLoop * 4 => ledCount; // Update LED count
                        <<< "✓ Beat length set to", beatsPerLoop, "beats (", ledCount, "LEDs)" >>>;
                        0 => listening;
                    }
                    else
                    {
                        <<< "Invalid! Enter 1-16" >>>;
                        "" => input;
                    }
                }
            }
            // Number keys 0-9 (ASCII 48-57)
            else if (k >= 48 && k <= 57)
            {
                if (input.length() < 2) // Max 2 digits
                {
                    input + Std.itoa(k - 48) => input;
                    // Print the actual number character
                    chout <= Std.itoa(k - 48);
                    chout.flush();
                }
            }
            // Backspace (ASCII 8 or 127)
            else if (k == 8 || k == 127)
            {
                if (input.length() > 0)
                {
                    input.substring(0, input.length() - 1) => input;
                    chout <= "\b \b";
                    chout.flush();
                }
            }
            // Escape (ASCII 27) to cancel
            else if (k == 27)
            {
                <<< "\nCancelled" >>>;
                0 => listening;
            }
        }
    }
}

// ------------------------------------------------------
// Record Initial Loop (Measure or Free Mode)
// ------------------------------------------------------
fun void recordLoop()
{
    if (measureMode)
    {
        // MEASURE MODE: 5-beat loop
        recordMeasureLoop();
    }
    else
    {
        // FREE MODE: Toggle recording on/off
        if (isRecording)
        {
            // Stop recording
            stopFreeRecording();
        }
        else
        {
            // Start recording
            startFreeRecording();
        }
    }
}

// Record measure loop with configurable beat length
fun void recordMeasureLoop()
{
    1 => isRecording;

    // If playback is active, wait for the next loop to start for sync
    if (isPlaying)
    {
        <<< "Waiting for next loop to start recording…" >>>;
        loopStart => now;
        <<< "RECORDING new", beatsPerLoop, "-beat loop…" >>>;
    }
    else
    {
        // Only use metronome countdown when recording the first loop (one extra beat)
        <<< "RECORDING", beatsPerLoop + 1, "beats –", beatsPerLoop + 1, "-beat countdown…" >>>;
        
        // --- Metronome countdown ---
        for (0 => int i; i < beatsPerLoop + 1; i++)
        {
            showLED(i * 4); // Light up every 4th LED (start of each beat)
            spork ~ playClick();
            beatDur => now;
        }
    }

    beatsPerLoop * beatDur => loopLength;
    
    // Configure LiSa buffer for main loop
    mainLoop.duration(loopLength);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(0::ms);  // No ramp for precise timing
    mainLoop.loopStart(0::ms);
    mainLoop.record(1);  // Start recording

    // Record exactly beatsPerLoop beats using simple beat timing
    for (0 => int beat; beat < beatsPerLoop; beat++)
    {
        for (0 => int sub; sub < 4; sub++)
        {
            showLED(beat * 4 + sub);
            beatDur / 4.0 => now;
        }
    }

    mainLoop.record(0);  // Stop recording
    mainLoop.loopEnd(loopLength);  // Set loop end AFTER recording
    0 => isRecording;
    1 => loopExists;
    <<< "LOOP RECORDED!" >>>;
    
    // Start playback directly (not spawned - we're already in a spawned shred)
    startPlayback();
}

// Start free recording
fun void startFreeRecording()
{
    1 => isRecording;
    now => recordStart;
    
    <<< "● RECORDING... Press [r] again to stop" >>>;
    
    // Set a large buffer size (e.g., 60 seconds max)
    60::second => dur maxDuration;
    mainLoop.duration(maxDuration);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(0::ms);  // No ramp for precise timing
    mainLoop.loopStart(0::ms);  // Set loop start
    mainLoop.record(1);  // Start recording
}

// Stop free recording and start playback
fun void stopFreeRecording()
{
    mainLoop.record(0);  // Stop recording
    
    // Calculate actual recorded length
    now - recordStart => loopLength;
    
    // DON'T resize buffer - it clears the content!
    // Just set the loop length for playback
    mainLoop.loopEnd(loopLength);
    
    0 => isRecording;
    1 => loopExists;
    <<< "○ LOOP RECORDED!", (loopLength/second), "seconds" >>>;
    
    // Start playback
    startPlayback();
}

time recordStart;  // Track when recording started

// ------------------------------------------------------
// HID Setup and iRig BlueTurn Handler
// ------------------------------------------------------

// Function to open BlueTurn HID device
fun int openBlueTurn()
{
    // BlueTurn is device 0 based on chuck --probe
    if (!blueTurn.openKeyboard(0))
    {
        <<< "Could not open BlueTurn (HID keyboard device 0)" >>>;
        return 0;
    }
    <<< "✓ BlueTurn connected:", blueTurn.name() >>>;
    return 1;
}

// BlueTurn listener thread
fun void blueTurnListener()
{
    while (true)
    {
        blueTurn => now;
        
        while (blueTurn.recv(blueTurnMsg))
        {
            // Only respond to button down events
            if (blueTurnMsg.isButtonDown())
            {
                blueTurnMsg.which => int button;
                
                // Button 1 (Page Down): Smart Record/Overdub
                if (button == BUTTON_1)
                {
                    if (!loopExists)
                    {
                        if (measureMode && isRecording)
                        {
                            // Do nothing - already recording
                        }
                        else
                        {
                            spork ~ recordLoop();
                        }
                    }
                    else if (isPlaying)
                    {
                        spork ~ recordOverdub();
                    }
                    else
                    {
                        spork ~ recordLoop();
                    }
                }
                // Button 2 (Page Up): Play/Stop
                else if (button == BUTTON_2)
                {
                    if (isPlaying) 
                    {
                        0 => isPlaying;
                    }
                    else if (loopExists) 
                    {
                        spork ~ startPlayback();
                    }
                    else 
                    {
                        <<< "Record first with Button 1" >>>;
                    }
                }
            }
        }
    }
}

// ------------------------------------------------------
// Metronome Click
// ------------------------------------------------------

// ------------------------------------------------------
// ------------------------------------------------------
// Metronome Click
// ------------------------------------------------------
fun void playClick()
{
    // UGens for the click sound
    SinOsc s => ADSR env => clickGain;

    // Configure the click
    880 => s.freq; // A clear frequency for the click
    env.set(1::ms, 49::ms, 0.0, 1::ms); // Short attack, quick decay, no sustain

    // Trigger the envelope and let it play out
    env.keyOn();
    50::ms => now;
    // env.keyOff() is not strictly needed here as the sound decays to zero anyway
}

// ------------------------------------------------------
// Playback – uses flag for break
// ------------------------------------------------------
fun void startPlayback()
{
    if (!loopExists) return;
    1 => isPlaying;

    // Start main loop playback
    mainLoop.playPos(0::ms);
    mainLoop.loopStart(0::ms);
    mainLoop.loopEnd(loopLength);
    mainLoop.loopEndRec(loopLength - 5::ms);  // Start crossfade 5ms before end
    mainLoop.loop(1);  // Enable looping
    mainLoop.play(mainLoopActive);

    // Start all existing overdubs
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].playPos(0::ms);
        overdubPlayers[i].loopStart(0::ms);
        overdubPlayers[i].loopEnd(loopLength);
        overdubPlayers[i].loopEndRec(loopLength - 5::ms);  // 5ms crossfade
        overdubPlayers[i].loop(1);
        overdubPlayers[i].play(overdubActive[i]);
    }

    loopStart.broadcast();

    <<< "PLAYING…" >>>;

    while (isPlaying && loopExists)
    {
        1 => int stepDone;
        
        if (measureMode)
        {
            // MEASURE MODE: Show LED ring animation
            for (0 => int s; s < ledCount; s++)
            {
                if (!isPlaying)
                {
                    0 => stepDone;
                    break;
                }
                showLED(s);
                (loopLength / ledCount) => now;
            }
        }
        else
        {
            // FREE MODE: Show fixed LED ring as reference
            // Divide loop into ledCount segments for visual reference
            (loopLength / ledCount) => dur segment;
            for (0 => int s; s < ledCount; s++)
            {
                if (!isPlaying)
                {
                    0 => stepDone;
                    break;
                }
                showLED(s);
                segment => now;
            }
        }
        
        if (!stepDone) break;

        if (isPlaying)
        {
            loopStart.broadcast();
        }
    }

    // Stop playback
    mainLoop.play(0);

    // Stop all overdubs
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].play(0);
    }

    0 => isPlaying;
    <<< "STOPPED." >>>;
}

// ------------------------------------------------------
// SEAMLESS OVERDUB – audible live input
// ------------------------------------------------------
fun void recordOverdub()
{
    if (!isPlaying || !loopExists)
    {
        <<< "Play loop first [p]" >>>;
        return;
    }

    if (isOverdubbing)
    {
        <<< "Overdub already in progress..." >>>;
        return;
    }

    if (overdubCount >= 10)
    {
        <<< "Maximum overdubs (10) reached!" >>>;
        return;
    }

    // Both modes: Wait for loop start for sync
    <<< "OVERDUB", overdubCount + 1, "– waiting for next loop…" >>>;
    loopStart => now;
    
    1 => isOverdubbing;
    <<< "OVERDUB", overdubCount + 1, "RECORDING..." >>>;
    
    // Configure LiSa buffer for this overdub
    overdubPlayers[overdubCount].duration(loopLength);
    overdubPlayers[overdubCount].recPos(0::ms);
    overdubPlayers[overdubCount].recRamp(0::ms);  // No ramp for precise timing
    overdubPlayers[overdubCount].loopStart(0::ms);
    overdubPlayers[overdubCount].loopEnd(loopLength);
    overdubPlayers[overdubCount].record(1);
    
    // Record for exactly one loop length
    loopLength => now;
    
    // Stop recording
    overdubPlayers[overdubCount].record(0);
    
    0 => isOverdubbing;
    
    // Start playback of the new overdub, synced to main loop
    overdubPlayers[overdubCount].playPos(mainLoop.playPos());  // Sync to current position
    overdubPlayers[overdubCount].loopEndRec(loopLength - 5::ms);  // 5ms crossfade
    overdubPlayers[overdubCount].loop(1);
    overdubPlayers[overdubCount].play(1);
    
    overdubCount++;
    <<< "OVERDUB", overdubCount, "RECORDED! Total overdubs:", overdubCount >>>;
}

// Re-record the last overdub
fun void redoLastOverdub()
{
    if (!isPlaying || !loopExists)
    {
        <<< "Play loop first [p]" >>>;
        return;
    }

    if (overdubCount == 0)
    {
        <<< "No overdub to re-record. Press 'o' to create one." >>>;
        return;
    }

    if (isOverdubbing)
    {
        <<< "Overdub already in progress..." >>>;
        return;
    }

    overdubCount - 1 => int lastIndex;
    
    // Both modes: Wait for loop start for sync
    <<< "RE-RECORDING overdub", overdubCount, "– waiting for next loop…" >>>;
    loopStart => now;
    
    1 => isOverdubbing;
    <<< "RE-RECORDING overdub", overdubCount, "(", beatsPerLoop, "beats)..." >>>;
    
    // Stop playback of the last overdub and clear it
    overdubPlayers[lastIndex].play(0);
    
    // Re-configure LiSa buffer (this clears the old content)
    overdubPlayers[lastIndex].duration(loopLength);
    overdubPlayers[lastIndex].recPos(0::ms);
    overdubPlayers[lastIndex].recRamp(0::ms);  // No ramp for precise timing
    overdubPlayers[lastIndex].loopStart(0::ms);
    overdubPlayers[lastIndex].loopEnd(loopLength);
    overdubPlayers[lastIndex].record(1);
    
    // Record for exactly one loop length
    loopLength => now;
    
    // Stop recording
    overdubPlayers[lastIndex].record(0);
    
    0 => isOverdubbing;
    
    // Start playback of the re-recorded overdub, synced to main loop
    overdubPlayers[lastIndex].playPos(mainLoop.playPos());  // Sync to current position
    overdubPlayers[lastIndex].loopEndRec(loopLength - 5::ms);  // 5ms crossfade
    overdubPlayers[lastIndex].loop(1);
    overdubPlayers[lastIndex].play(1);
    
    <<< "OVERDUB", overdubCount, "RE-RECORDED!" >>>;
}

// ------------------------------------------------------
// MAIN LOOP
// ------------------------------------------------------
<<< "\n=== VINTAGE LOOP STATION ===" >>>;

// Try to connect BlueTurn
<<< "Attempting to connect iRig BlueTurn..." >>>;
if (openBlueTurn())
{
    1 => useHid;
    spork ~ blueTurnListener();
    <<< "✓ BlueTurn ready!" >>>;
    <<< "  Button 1 (Page Down): Record/Overdub (smart)" >>>;
    <<< "  Button 2 (Page Up): Play/Stop" >>>;
}
else
{
    <<< "BlueTurn not found - using keyboard only" >>>;
}

<<< "\nSelect mode:" >>>;
<<< "[1] Measure Mode - Configurable beat loops with tap tempo (default:", beatsPerLoop, "beats)" >>>;
<<< "[2] Free Mode - Record start/stop on keypress, any duration" >>>;

// Mode selection
KBHit kb;
1 => int modeSelected;
while (modeSelected)
{
    kb => now;
    kb.getchar() => int k;
    
    if (k == '1')
    {
        1 => measureMode;
        0 => modeSelected;
        <<< "\n✓ MEASURE MODE selected (", beatsPerLoop, "beats per loop)" >>>;
        <<< "[t] Tap Tempo | [b] Set Beat Length | [r] Record loop | [p] Play/Stop | [o] Add Overdub | [u] Redo Last | [0-9] Toggle Loops | [q] Quit" >>>;
    }
    else if (k == '2')
    {
        0 => measureMode;
        0 => modeSelected;
        <<< "\n✓ FREE MODE selected" >>>;
        <<< "[r] Start/Stop Recording | [p] Play/Stop | [o] Add Overdub | [u] Redo Last | [0-9] Toggle Loops | [q] Quit" >>>;
    }
}

while (true)
{
    kb => now;
    kb.getchar() => int k;

    if (k == 't' && measureMode) spork ~ tapTempo();
    else if (k == 'b' && measureMode) setBeatLength();
    else if (k == 'r')
    {
        // In measure mode, only start if not already recording
        // In free mode, allow toggle
        if (measureMode && isRecording)
        {
            // Do nothing - already recording in measure mode
        }
        else
        {
            spork ~ recordLoop();
        }
    }
    else if (k == 'p')
    {
        if (isPlaying) 0 => isPlaying;
        else if (loopExists) spork ~ startPlayback();
        else <<< "Record first [r]" >>>;
    }
    else if (k == 'o')
    {
        spork ~ recordOverdub();
    }
    else if (k == 'u')
    {
        spork ~ redoLastOverdub();
    }
    // Toggle loops with number keys
    else if (k >= '0' && k <= '9')
    {
        k - '0' => int loopNum;
        if (loopNum == 0)
        {
            // Toggle main loop
            if (loopExists && isPlaying)
            {
                !mainLoopActive => mainLoopActive;
                // Control via gain for instant mute/unmute without sync issues
                if (mainLoopActive) mainLoop.gain(0.9);
                else mainLoop.gain(0.0);
                if (mainLoopActive) <<< "Main loop ON" >>>;
                else <<< "Main loop OFF" >>>;
            }
        }
        else
        {
            loopNum - 1 => int overdubIndex;
            if (overdubIndex < overdubCount && isPlaying)
            {
                !overdubActive[overdubIndex] => overdubActive[overdubIndex];
                // Control via gain for instant mute/unmute without sync issues
                if (overdubActive[overdubIndex]) overdubPlayers[overdubIndex].gain(0.9);
                else overdubPlayers[overdubIndex].gain(0.0);
                if (overdubActive[overdubIndex]) <<< "Overdub", loopNum, "ON" >>>;
                else <<< "Overdub", loopNum, "OFF" >>>;
            }
        }
    }
    else if (k == 'q')
    {
        if (loopExists)
        {
            <<< "\nSave final mix to WAV? [y/n]" >>>;
            kb => now;
            kb.getchar() => int answer;
            
            if (answer == 'y' || answer == 'Y')
            {
                <<< "Recording final mix..." >>>;
                
                // If playing, wait for next loop start for clean recording
                if (isPlaying)
                {
                    <<< "Waiting for loop start..." >>>;
                    loopStart => now;
                }
                
                // Create output file
                "final_mix.wav" => string filename;
                WvOut wout => blackhole;
                wout.wavFilename(filename);
                
                // Connect main loop and all overdubs to output
                mainLoop => wout;
                for (0 => int i; i < overdubCount; i++)
                {
                    overdubPlayers[i] => wout;
                }
                
                // If not playing, start everything from the beginning
                if (!isPlaying)
                {
                    mainLoop.playPos(0::ms);
                    mainLoop.loopStart(0::ms);
                    mainLoop.loopEnd(loopLength);
                    mainLoop.loopEndRec(loopLength - 5::ms);
                    mainLoop.loop(1);
                    mainLoop.play(1);
                    
                    // Set correct gain based on active state
                    if (mainLoopActive) mainLoop.gain(0.9);
                    else mainLoop.gain(0.0);
                    
                    for (0 => int i; i < overdubCount; i++)
                    {
                        overdubPlayers[i].playPos(0::ms);
                        overdubPlayers[i].loopStart(0::ms);
                        overdubPlayers[i].loopEnd(loopLength);
                        overdubPlayers[i].loopEndRec(loopLength - 5::ms);
                        overdubPlayers[i].loop(1);
                        overdubPlayers[i].play(1);
                        
                        // Set correct gain based on active state
                        if (overdubActive[i]) overdubPlayers[i].gain(0.9);
                        else overdubPlayers[i].gain(0.0);
                    }
                }
                
                <<< "Recording..." >>>;
                // Record exactly one loop
                loopLength => now;
                
                wout.closeFile();
                <<< "✓ Saved as", filename >>>;
            }
        }
        
        <<< "Loop station stopped. Bye!" >>>;
        me.exit();
    }
}


