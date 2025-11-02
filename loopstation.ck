// ======================================================
// Vintage Loop Station (BOSS RC-1 style) - Pedro Alcacer 2025
// ======================================================
// Features:
//  • Tap tempo (press 't' twice or more)
//  • LED-style console loop indicator
//  • Record one 4-beat loop
//  • Play / Stop / Overdub
//  • Keyboard controls instead of foot pedal
// ======================================================

// audio routing
adc => Gain input => blackhole;

// SndBuf for playback
SndBuf player => dac;
player.gain(0.9);

// ------------------------------------------------------
// Variables
// ------------------------------------------------------
now => time lastTap;
0 => int firstTap;
120.0 => float bpm;
(60.0 / bpm) :: second => dur beatDur;

0 => int recording;
0 => int playing;
0 => int overdubbing;
16 => int ledCount; // number of LED "steps" in ring

// ------------------------------------------------------
// Functions
// ------------------------------------------------------

// --- show LED ring in console ---
fun void showLED(int pos)
{
    "" => string leds;
    for (0 => int i; i < ledCount; i++)
    {
        if (i == pos) leds + "●" => leds;
        else leds + "○" => leds;
    }
    <<< leds >>>;
}

// --- Tap tempo ---
fun void tapTempo()
{
    now => time currentTap;
    if (firstTap)
    {
        (currentTap - lastTap) => dur delta;
        (60.0 / (delta / second)) => float newBPM;
        newBPM => bpm;
        (60.0 / bpm) :: second => beatDur;
        <<< "Tempo set to", bpm, "BPM" >>>;
    }
    else
    {
        1 => firstTap; // mark first tap occurred
        <<< "Tap once more to set tempo..." >>>;
    }
    currentTap => lastTap;
}

// --- Record one loop cycle (4 beats) ---
fun void recordLoop()
{
    adc => WvOut w => blackhole;
    "loop.wav" => w.wavFilename;
    <<< "Recording one full cycle at", bpm, "BPM" >>>;

    4 * beatDur => dur loopLen;
    now + loopLen => time end;

    while (now < end)
    {
        10::ms => now;
    }

    w.closeFile();
    <<< "Recording complete!" >>>;
    0 => recording;
    1 => playing;
    spork ~ playLoop(loopLen);
}

// --- Play loop and LED indicator ---
fun void playLoop(dur loopLen)
{
    "loop.wav" => player.read;
    player.pos(0);
    player.play();
    <<< "Loop playing..." >>>;

    while (playing)
    {
        for (0 => int i; i < ledCount && playing; i++)
        {
            showLED(i);
            (loopLen / ledCount) => now;
        }
        // restart at end of loop
        player.pos(0);
        player.play();
    }

    <<< "Stopped loop." >>>;
}

// --- Overdub (simple live mix) ---
fun void overdub()
{
    <<< "Overdub mode ON" >>>;
    1 => overdubbing;
    adc => Gain live => dac;
    0.5 => live.gain;

    while (overdubbing)
    {
        10::ms => now;
    }

    live =< dac;
    <<< "Overdub mode OFF" >>>;
}

// ------------------------------------------------------
// Main Control Loop
// ------------------------------------------------------
<<< "\n--- VINTAGE LOOP STATION ---" >>>;
<<< "[t] Tap tempo | [r] Record | [p] Play/Stop | [o] Overdub | [q] Quit" >>>;

KBHit kb;
while (true)
{
    kb => now;
    kb.getchar() => int key;

    if (key == 't')
    {
        tapTempo();
    }
    else if (key == 'r')
    {
        if (!recording)
        {
            1 => recording;
            spork ~ recordLoop();
        }
    }
    else if (key == 'p')
    {
        if (playing)
        {
            0 => playing;
        }
        else
        {
            1 => playing;
            spork ~ playLoop(4 * beatDur);
        }
    }
    else if (key == 'o')
    {
        if (!overdubbing) spork ~ overdub();
        else 0 => overdubbing;
    }
    else if (key == 'q')
    {
        <<< "Goodbye!" >>>;
        me.exit();
    }
}
