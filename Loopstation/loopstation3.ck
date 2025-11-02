// VINTAGE LOOP STATION – EXACT ○● SYMBOLS
// Seamless, audible overdub, terminal/miniAudicle, 4-step beat
// ======================================================

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
16 => int ledCount;

// Mode selection: 0 = free mode, 1 = measure mode (4-beat)
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
        
        // Add spacing every 4 beats for readability
        if ((i + 1) % 4 == 0 && i < ledCount - 1) leds + "  " => leds;
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
        if (newBPM > 40 && newBPM < 300)

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
// Record Initial Loop (Measure or Free Mode)
// ------------------------------------------------------
fun void recordLoop()
{
    if (measureMode)
    {
        // MEASURE MODE: 4-beat loop
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

// Record 4-beat loop (measure mode)
fun void recordMeasureLoop()
{
    1 => isRecording;

    // If playback is active, wait for the next loop to start for sync
    if (isPlaying)
    {
        <<< "Waiting for next loop to start recording…" >>>;
        loopStart => now;
        <<< "RECORDING new 4-beat loop…" >>>;
    }
    else
    {
        // Only use metronome countdown when recording the first loop
        <<< "RECORDING 4 beats – 4-beat countdown…" >>>;
        
        // --- Metronome countdown ---
        for (0 => int i; i < 4; i++)
        {
            showLED(i * 4); // Light up 0, 4, 8, 12
            spork ~ playClick();
            beatDur => now;
        }
    }

    4 * beatDur => loopLength;
    
    // Configure LiSa buffer for main loop
    mainLoop.duration(loopLength);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(50::ms);
    mainLoop.record(1);  // Start recording

    for (0 => int s; s < 16; s++)
    {
        showLED(s);
        (loopLength / 16) => now;
    }

    mainLoop.record(0);  // Stop recording
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
    now => time recordStart;
    
    <<< "● RECORDING... Press [r] again to stop" >>>;
    
    // Set a large buffer size (e.g., 60 seconds max)
    60::second => dur maxDuration;
    mainLoop.duration(maxDuration);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(50::ms);
    mainLoop.record(1);  // Start recording
}

// Stop free recording and start playback
fun void stopFreeRecording()
{
    mainLoop.record(0);  // Stop recording
    
    // Calculate actual recorded length
    now - recordStart => loopLength;
    
    // Adjust buffer to actual length
    mainLoop.duration(loopLength);
    
    0 => isRecording;
    1 => loopExists;
    <<< "○ LOOP RECORDED!", (loopLength/second), "seconds" >>>;
    
    // Start playback
    startPlayback();
}

time recordStart;  // Track when recording started

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
    mainLoop.loop(1);  // Enable looping
    mainLoop.play(mainLoopActive);

    // Start all existing overdubs
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].playPos(0::ms);
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
            // MEASURE MODE: Show LED ring
            for (0 => int s; s < 16; s++)
            {
                if (!isPlaying)
                {
                    0 => stepDone;
                    break;
                }
                showLED(s);
                (loopLength / 16) => now;
            }
        }
        else
        {
            // FREE MODE: Just loop and broadcast
            loopLength => now;
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

    if (measureMode)
    {
        // MEASURE MODE: Wait for loop start for sync
        <<< "OVERDUB", overdubCount + 1, "– waiting for next loop…" >>>;
        loopStart => now;
    }
    
    1 => isOverdubbing;
    <<< "OVERDUB", overdubCount + 1, "RECORDING..." >>>;
    
    // Configure LiSa buffer for this overdub
    overdubPlayers[overdubCount].duration(loopLength);
    overdubPlayers[overdubCount].recPos(0::ms);
    overdubPlayers[overdubCount].recRamp(50::ms);
    overdubPlayers[overdubCount].record(1);
    
    // Record for exactly one loop length
    loopLength => now;
    
    // Stop recording
    overdubPlayers[overdubCount].record(0);
    
    0 => isOverdubbing;
    
    // Start playback of the new overdub
    overdubPlayers[overdubCount].playPos(0::ms);
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
    
    if (measureMode)
    {
        // MEASURE MODE: Wait for loop start for sync
        <<< "RE-RECORDING overdub", overdubCount, "– waiting for next loop…" >>>;
        loopStart => now;
    }
    else
    {
        <<< "RE-RECORDING overdub", overdubCount, "..." >>>;
    }
    
    1 => isOverdubbing;
    <<< "RE-RECORDING overdub", overdubCount, "(4 beats)..." >>>;
    
    // Stop playback of the last overdub and clear it
    overdubPlayers[lastIndex].play(0);
    
    // Re-configure LiSa buffer (this clears the old content)
    overdubPlayers[lastIndex].duration(loopLength);
    overdubPlayers[lastIndex].recPos(0::ms);
    overdubPlayers[lastIndex].recRamp(50::ms);
    overdubPlayers[lastIndex].record(1);
    
    // Record for exactly one loop length
    loopLength => now;
    
    // Stop recording
    overdubPlayers[lastIndex].record(0);
    
    0 => isOverdubbing;
    
    // Start playback of the re-recorded overdub
    overdubPlayers[lastIndex].playPos(0::ms);
    overdubPlayers[lastIndex].loop(1);
    overdubPlayers[lastIndex].play(1);
    
    <<< "OVERDUB", overdubCount, "RE-RECORDED!" >>>;
}

// ------------------------------------------------------
// MAIN LOOP
// ------------------------------------------------------
<<< "\n=== VINTAGE LOOP STATION ===" >>>;
<<< "\nSelect mode:" >>>;
<<< "[1] Measure Mode - 4-beat loops with tap tempo" >>>;
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
        <<< "\n✓ MEASURE MODE selected" >>>;
        <<< "[t] Tap Tempo | [r] Record 4-beat loop | [p] Play/Stop | [o] Add Overdub | [u] Redo Last | [0-9] Toggle Loops | [q] Quit" >>>;
    }
    else if (k == '2')
    {
        0 => measureMode;
        0 => modeSelected;
        <<< "\n✓ FREE MODE selected" >>>;
        <<< "[r] Start Recording | [r again] Stop & Loop | [p] Play/Stop | [o] Add Overdub | [u] Redo Last | [0-9] Toggle Loops | [q] Quit" >>>;
    }
}

while (true)
{
    kb => now;
    kb.getchar() => int k;

    if (k == 't' && measureMode) spork ~ tapTempo();
    else if (k == 'r' && !isRecording) spork ~ recordLoop();
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
                mainLoop.play(mainLoopActive);  // Apply the change immediately
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
                overdubPlayers[overdubIndex].play(overdubActive[overdubIndex]);  // Apply immediately
                if (overdubActive[overdubIndex]) <<< "Overdub", loopNum, "ON" >>>;
                else <<< "Overdub", loopNum, "OFF" >>>;
            }
        }
    }
    else if (k == 'q')
    {
        <<< "Loop station stopped. Bye!" >>>;
        me.exit();
    }
}


