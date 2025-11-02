// VINTAGE LOOP STATION – EXACT ○● SYMBOLS
// Seamless, audible overdub, terminal/miniAudicle, 4-step beat
// ======================================================

adc => Gain input => blackhole;
input.gain(0.8);

SndBuf player => dac;
player.gain(0.9);

Gain clickGain => dac;
clickGain.gain(0.5);

"loop.wav"      => string mainLoop;

120.0 => float bpm;
(60.0 / bpm) :: second => dur beatDur;

dur loopLength;
0 => int isRecording;
0 => int isPlaying;
0 => int isOverdubbing;
0 => int loopExists;
16 => int ledCount;

// Multiple overdubs support
SndBuf overdubPlayers[10]; // Support up to 10 overdubs
string overdubFiles[10];
0 => int overdubCount;
int overdubActive[10]; // Track which overdubs are active
1 => int mainLoopActive; // Track if main loop is active

// Initialize overdub players and filenames
for (0 => int i; i < 10; i++)
{
    overdubPlayers[i] => dac;
    overdubPlayers[i].gain(0.9);
    "temp_loop" + i + ".wav" => overdubFiles[i];
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
// Record Initial 4-Beat Loop
// ------------------------------------------------------
fun void recordLoop()
{
    /*if (isRecording || loopExists) return;*/
    1 => isRecording;

    WvOut w => blackhole;

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

    w.wavFilename(mainLoop);
    adc => w;

    4 * beatDur => loopLength;

    for (0 => int s; s < 16; s++)
    {
        showLED(s);
        (loopLength / 16) => now;
    }

    w.closeFile();
    adc =< w;
    0 => isRecording;
    1 => loopExists;
    <<< "LOOP RECORDED!" >>>;

    // Small delay to ensure file is written and yield to scheduler
    50::ms => now;
    
    // Start playback directly (not spawned - we're already in a spawned shred)
    startPlayback();
}

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

    player.read(mainLoop);
    0 => player.pos;
    mainLoopActive => player.play;

    // Start all existing overdubs
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].read(overdubFiles[i]);
        0 => overdubPlayers[i].pos;
        overdubActive[i] => overdubPlayers[i].play;
    }

    loopStart.broadcast();

    <<< "PLAYING…" >>>;

    while (isPlaying && loopExists)
    {
        1 => int stepDone;
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
        if (!stepDone) break;

        if (isPlaying)
        {
            0 => player.pos;
            mainLoopActive => player.play;

            // Restart all overdubs
            for (0 => int i; i < overdubCount; i++)
            {
                0 => overdubPlayers[i].pos;
                overdubActive[i] => overdubPlayers[i].play;
            }

            loopStart.broadcast();
        }
    }

    0 => player.pos;
    0 => player.play;

    // Stop all overdubs
    for (0 => int i; i < overdubCount; i++)
    {
        0 => overdubPlayers[i].pos;
        0 => overdubPlayers[i].play;
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

    <<< "OVERDUB", overdubCount + 1, "– waiting for next loop…" >>>;
    
    // Wait for the next loop to start
    loopStart => now;
    
    1 => isOverdubbing;
    <<< "OVERDUB", overdubCount + 1, "RECORDING (4 beats)..." >>>;
    
    // Start recording to a new overdub file
    WvOut w => blackhole;
    w.wavFilename(overdubFiles[overdubCount]);
    adc => w;
    
    // Record for exactly one loop length
    loopLength => now;
    
    // Stop recording
    w.closeFile();
    adc =< w;
    
    0 => isOverdubbing;
    
    // Small delay to ensure file is written
    10::ms => now;
    
    // Load the new file into the corresponding player and set position
    overdubPlayers[overdubCount].read(overdubFiles[overdubCount]);
    0 => overdubPlayers[overdubCount].pos;
    
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
    <<< "RE-RECORDING overdub", overdubCount, "– waiting for next loop…" >>>;
    
    // Wait for the next loop to start
    loopStart => now;
    
    1 => isOverdubbing;
    <<< "RE-RECORDING overdub", overdubCount, "(4 beats)..." >>>;
    
    // Start recording to replace the last overdub file
    WvOut w => blackhole;
    w.wavFilename(overdubFiles[lastIndex]);
    adc => w;
    
    // Record for exactly one loop length
    loopLength => now;
    
    // Stop recording
    w.closeFile();
    adc =< w;
    
    0 => isOverdubbing;
    
    // Small delay to ensure file is written
    10::ms => now;
    
    // Reload the file
    overdubPlayers[lastIndex].read(overdubFiles[lastIndex]);
    0 => overdubPlayers[lastIndex].pos;
    
    <<< "OVERDUB", overdubCount, "RE-RECORDED!" >>>;
}

// ------------------------------------------------------
// MAIN LOOP
// ------------------------------------------------------
<<< "\n=== VINTAGE LOOP STATION ===" >>>;
<<< "tap a tempo then record inital loop and then make as many overdubs as you want!" >>>;
<<< "[t] Tap | [r] Record | [p] Play/Stop | [o] Add Overdub | [u] Redo Last | [0-9] Toggle Loops | [q] Quit" >>>;

KBHit kb;
while (true)
{
    kb => now;
    kb.getchar() => int k;

    if (k == 't') spork ~ tapTempo();
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
            if (loopExists)
            {
                !mainLoopActive => mainLoopActive;
                if (mainLoopActive) <<< "Main loop ON" >>>;
                else <<< "Main loop OFF" >>>;
            }
        }
        else
        {
            loopNum - 1 => int overdubIndex;
            if (overdubIndex < overdubCount)
            {
                !overdubActive[overdubIndex] => overdubActive[overdubIndex];
                if (overdubActive[overdubIndex]) <<< "Overdub", loopNum, "ON" >>>;
                else <<< "Overdub", loopNum, "OFF" >>>;
            }
        }
    }
    else if (k == 'q')
    {
        <<< "Saved as 'loop.wav'. Bye!" >>>;
        me.exit();
    }
}


