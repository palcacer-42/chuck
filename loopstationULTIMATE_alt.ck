// VINTAGE LOOP STATION – IMPROVED ○● SYMBOLS
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

// Main loop using LiSa buffer with separate monitor gain
LiSa mainLoop => Gain mainLoopMonitor => dac;
adc => mainLoop;
mainLoop.gain(1.0);
mainLoop.maxVoices(1);
mainLoopMonitor.gain(0.9);

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
10 => int MAX_OVERDUBS;
LiSa overdubPlayers[MAX_OVERDUBS];
Gain overdubMonitor[MAX_OVERDUBS];
0 => int overdubCount;
int overdubActive[MAX_OVERDUBS];
1 => int mainLoopActive;

// Initialize overdub players with LiSa buffers and separate monitor gains
for (0 => int i; i < MAX_OVERDUBS; i++)
{
    adc => overdubPlayers[i];
    overdubPlayers[i] => overdubMonitor[i] => dac;
    overdubPlayers[i].gain(1.0);
    overdubPlayers[i].maxVoices(1);
    overdubMonitor[i].gain(0.9);
    1 => overdubActive[i];
}

// Guards against duplicate command sporks
0 => int recordLoopInFlight;
0 => int playbackInFlight;
0 => int overdubInFlight;
0 => int redoInFlight;

Event loopStart;

0 => int tapCount;
time lastTap;
0 => int tapResetVersion;

80 => int consoleWidth;

fun string fmtInt(int value)
{
    return Std.itoa(value);
}

fun string fmtFloat(float value)
{
    return Std.ftoa(value, 2);
}

fun void clearStatusLine()
{
    chout <= "\r";
    for (0 => int i; i < consoleWidth; i++) chout <= " ";
    chout <= "\r";
    chout.flush();
}

fun void printLine(string msg)
{
    clearStatusLine();
    chout <= msg <= "\n";
    chout.flush();
}

fun void printInline(string msg)
{
    clearStatusLine();
    chout <= msg;
    chout.flush();
}

fun void printBlock(string msg)
{
    clearStatusLine();
    chout <= "\n" <= msg <= "\n";
    chout.flush();
}

// ------------------------------------------------------
// Utility helpers for monitor routing
// ------------------------------------------------------
fun void setMainLoopMonitor(int active)
{
    if (active) mainLoopMonitor.gain(0.9);
    else mainLoopMonitor.gain(0.0);
}

fun void setOverdubMonitor(int index, int active)
{
    if (active) overdubMonitor[index].gain(0.9);
    else overdubMonitor[index].gain(0.0);
}

fun void syncMonitorState()
{
    setMainLoopMonitor(mainLoopActive);
    for (0 => int i; i < overdubCount; i++)
    {
        setOverdubMonitor(i, overdubActive[i]);
    }
}

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

fun int animateLedRing(dur totalDuration)
{
    if (ledCount <= 0) return 0;
    totalDuration / ledCount => dur segment;
    for (0 => int s; s < ledCount; s++)
    {
        if (!isPlaying) return 0;
        showLED(s);
        segment => now;
    }
    return 1;
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
            "TEMPO: " => string msg;
            msg + fmtFloat(bpm) => msg;
            msg + " BPM" => msg;
            printLine(msg);
        }
    }
    else
    {
        printLine("First tap – tap again…");
    }
    cur => lastTap;
    tapCount + 1 => tapCount;
    tapResetVersion + 1 => tapResetVersion;
    spork ~ resetTapCount(tapResetVersion);
}

fun void resetTapCount(int version)
{
    2::second => now;
    if (version == tapResetVersion)
    {
        0 => tapCount;
    }
}

// ------------------------------------------------------
// Set Beat Length
// ------------------------------------------------------
fun void setBeatLength()
{
    if (isPlaying || loopExists)
    {
        printLine("Cannot change beat length while loop exists. Stop and clear first.");
        return;
    }
    
    printBlock("Enter number of beats (1-9, or press 1 then 0-6 for 10-16), then press Enter:");
    
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
                        "✓ Beat length set to " => string msg;
                        msg + fmtInt(beatsPerLoop) => msg;
                        msg + " beats (" => msg;
                        msg + fmtInt(ledCount) => msg;
                        msg + " LEDs)" => msg;
                        printLine(msg);
                        0 => listening;
                    }
                    else
                    {
                        printLine("Invalid! Enter 1-16");
                        "" => input;
                    }
                }
            }
            // Number keys 0-9 (ASCII 48-57)
            else if (k >= 48 && k <= 57)
            {
                if (input.length() < 2)
                {
                    input + Std.itoa(k - 48) => input;
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
                printBlock("Cancelled");
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
    if (recordLoopInFlight) return;
    1 => recordLoopInFlight;
    
    if (measureMode)
    {
        recordMeasureLoop();
    }
    else
    {
        if (isRecording)
        {
            stopFreeRecording();
        }
        else
        {
            startFreeRecording();
        }
    }
    
    0 => recordLoopInFlight;
}

// Record measure loop with configurable beat length
fun void recordMeasureLoop()
{
    1 => isRecording;

    // If playback is active, wait for the next loop to start for sync
    if (isPlaying)
    {
        printLine("Waiting for next loop to start recording…");
        loopStart => now;
        "RECORDING new " => string msg;
        msg + fmtInt(beatsPerLoop) => msg;
        msg + "-beat loop…" => msg;
        printLine(msg);
    }
    else
    {
        beatsPerLoop + 1 => int countdownBeats;
        "RECORDING " => string msg;
        msg + fmtInt(countdownBeats) => msg;
        msg + " beats – " => msg;
        msg + fmtInt(countdownBeats) => msg;
        msg + "-beat countdown…" => msg;
        printLine(msg);
        
        for (0 => int i; i < beatsPerLoop + 1; i++)
        {
            showLED(i * 4);
            spork ~ playClick();
            beatDur => now;
        }
    }

    beatsPerLoop * beatDur => loopLength;
    
    mainLoop.duration(loopLength);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(0::ms);
    mainLoop.loopStart(0::ms);
    mainLoop.record(1);

    for (0 => int beat; beat < beatsPerLoop; beat++)
    {
        for (0 => int sub; sub < 4; sub++)
        {
            showLED(beat * 4 + sub);
            beatDur / 4.0 => now;
        }
    }

    mainLoop.record(0);
    mainLoop.loopEnd(loopLength);
    0 => isRecording;
    1 => loopExists;
    printLine("LOOP RECORDED!");
    
    startPlayback();
}

// Start free recording
fun void startFreeRecording()
{
    1 => isRecording;
    now => recordStart;
    
    printLine("● RECORDING... Press [r] again to stop");
    
    60::second => dur maxDuration;
    mainLoop.duration(maxDuration);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(0::ms);
    mainLoop.loopStart(0::ms);
    mainLoop.record(1);
}

// Stop free recording and start playback
fun void stopFreeRecording()
{
    mainLoop.record(0);
    now - recordStart => loopLength;
    mainLoop.loopEnd(loopLength);
    0 => isRecording;
    1 => loopExists;
    loopLength / second => float lengthSec;
    "○ LOOP RECORDED! " => string msg;
    msg + fmtFloat(lengthSec) => msg;
    msg + " seconds" => msg;
    printLine(msg);
    startPlayback();
}

time recordStart;

// ------------------------------------------------------
// HID Setup and iRig BlueTurn Handler
// ------------------------------------------------------

fun int openBlueTurn()
{
    if (!blueTurn.openKeyboard(0))
    {
        printLine("Could not open BlueTurn (HID keyboard device 0)");
        return 0;
    }
    "✓ BlueTurn connected: " => string msg;
    msg + blueTurn.name() => msg;
    printLine(msg);
    return 1;
}

fun void blueTurnListener()
{
    while (true)
    {
        blueTurn => now;
        
        while (blueTurn.recv(blueTurnMsg))
        {
            if (blueTurnMsg.isButtonDown())
            {
                blueTurnMsg.which => int button;
                
                if (button == BUTTON_1)
                {
                    if (!loopExists)
                    {
                        if (!(measureMode && isRecording))
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
                        printLine("Record first with Button 1");
                    }
                }
            }
        }
    }
}

// ------------------------------------------------------
// Metronome Click
// ------------------------------------------------------
fun void playClick()
{
    SinOsc s => ADSR env => clickGain;
    880 => s.freq;
    env.set(1::ms, 49::ms, 0.0, 1::ms);
    env.keyOn();
    50::ms => now;
}

// ------------------------------------------------------
// Playback – uses flag for break
// ------------------------------------------------------
fun void startPlayback()
{
    if (!loopExists || playbackInFlight) return;
    1 => playbackInFlight;
    1 => isPlaying;

    mainLoop.playPos(0::ms);
    mainLoop.loopStart(0::ms);
    mainLoop.loopEnd(loopLength);
    mainLoop.loopEndRec(loopLength - 5::ms);
    mainLoop.loop(1);
    mainLoop.play(1);

    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].playPos(0::ms);
        overdubPlayers[i].loopStart(0::ms);
        overdubPlayers[i].loopEnd(loopLength);
        overdubPlayers[i].loopEndRec(loopLength - 5::ms);
        overdubPlayers[i].loop(1);
        overdubPlayers[i].play(1);
    }

    syncMonitorState();
    loopStart.broadcast();
    printLine("PLAYING…");

    while (isPlaying && loopExists)
    {
        if (!animateLedRing(loopLength)) break;
        if (!isPlaying) break;
        loopStart.broadcast();
    }

    mainLoop.play(0);

    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].play(0);
    }

    0 => isPlaying;
    0 => playbackInFlight;
    printLine("STOPPED.");
}

// ------------------------------------------------------
// SEAMLESS OVERDUB – audible live input
// ------------------------------------------------------
fun void recordOverdub()
{
    if (!isPlaying || !loopExists || overdubInFlight) return;
    if (isOverdubbing)
    {
        printLine("Overdub already in progress...");
        return;
    }
    
    if (overdubCount >= MAX_OVERDUBS)
    {
        "Maximum overdubs (" => string msg;
        msg + fmtInt(MAX_OVERDUBS) => msg;
        msg + ") reached!" => msg;
        printLine(msg);
        return;
    }

    1 => overdubInFlight;
    overdubCount + 1 => int nextOverdub;
    "OVERDUB " => string waitMsg;
    waitMsg + fmtInt(nextOverdub) => waitMsg;
    waitMsg + " – waiting for next loop…" => waitMsg;
    printLine(waitMsg);
    loopStart => now;
    
    1 => isOverdubbing;
    "OVERDUB " => string recMsg;
    recMsg + fmtInt(nextOverdub) => recMsg;
    recMsg + " RECORDING..." => recMsg;
    printLine(recMsg);
    
    overdubPlayers[overdubCount].duration(loopLength);
    overdubPlayers[overdubCount].recPos(0::ms);
    overdubPlayers[overdubCount].recRamp(0::ms);
    overdubPlayers[overdubCount].loopStart(0::ms);
    overdubPlayers[overdubCount].loopEnd(loopLength);
    overdubPlayers[overdubCount].record(1);
    
    loopLength => now;
    
    overdubPlayers[overdubCount].record(0);
    
    0 => isOverdubbing;
    overdubPlayers[overdubCount].playPos(mainLoop.playPos());
    overdubPlayers[overdubCount].loopEndRec(loopLength - 5::ms);
    overdubPlayers[overdubCount].loop(1);
    overdubPlayers[overdubCount].play(1);
    overdubMonitor[overdubCount].gain(0.9);
    1 => overdubActive[overdubCount];
    overdubCount++;
    "OVERDUB " => string doneMsg;
    doneMsg + fmtInt(overdubCount) => doneMsg;
    doneMsg + " RECORDED! Total overdubs: " => doneMsg;
    doneMsg + fmtInt(overdubCount) => doneMsg;
    printLine(doneMsg);
    0 => overdubInFlight;
}

// Re-record the last overdub
fun void redoLastOverdub()
{
    if (!isPlaying || !loopExists || redoInFlight) return;
    if (overdubCount == 0)
    {
        printLine("No overdub to re-record. Press 'o' to create one.");
        return;
    }
    
    if (isOverdubbing)
    {
        printLine("Overdub already in progress...");
        return;
    }
    
    1 => redoInFlight;
    overdubCount - 1 => int lastIndex;
    "RE-RECORDING overdub " => string waitMsg;
    waitMsg + fmtInt(overdubCount) => waitMsg;
    waitMsg + " – waiting for next loop…" => waitMsg;
    printLine(waitMsg);
    loopStart => now;
    
    1 => isOverdubbing;
    "RE-RECORDING overdub " => string recMsg;
    recMsg + fmtInt(overdubCount) => recMsg;
    recMsg + " (" => recMsg;
    recMsg + fmtInt(beatsPerLoop) => recMsg;
    recMsg + " beats)..." => recMsg;
    printLine(recMsg);
    
    overdubPlayers[lastIndex].play(0);
    overdubPlayers[lastIndex].duration(loopLength);
    overdubPlayers[lastIndex].recPos(0::ms);
    overdubPlayers[lastIndex].recRamp(0::ms);
    overdubPlayers[lastIndex].loopStart(0::ms);
    overdubPlayers[lastIndex].loopEnd(loopLength);
    overdubPlayers[lastIndex].record(1);
    
    loopLength => now;
    
    overdubPlayers[lastIndex].record(0);
    
    0 => isOverdubbing;
    overdubPlayers[lastIndex].playPos(mainLoop.playPos());
    overdubPlayers[lastIndex].loopEndRec(loopLength - 5::ms);
    overdubPlayers[lastIndex].loop(1);
    overdubPlayers[lastIndex].play(1);
    setOverdubMonitor(lastIndex, overdubActive[lastIndex]);
    "OVERDUB " => string doneMsg;
    doneMsg + fmtInt(overdubCount) => doneMsg;
    doneMsg + " RE-RECORDED!" => doneMsg;
    printLine(doneMsg);
    0 => redoInFlight;
}

// ------------------------------------------------------
// MAIN LOOP
// ------------------------------------------------------
printBlock("=== VINTAGE LOOP STATION (ALT) ===");

printLine("Attempting to connect iRig BlueTurn...");
if (openBlueTurn())
{
    1 => useHid;
    spork ~ blueTurnListener();
    printBlock("✓ BlueTurn ready!\n  Button 1 (Page Down): Record/Overdub (smart)\n  Button 2 (Page Up): Play/Stop");
}
else
{
    printLine("BlueTurn not found - using keyboard only");
}

"Select mode:\n[1] Measure Mode - Configurable beat loops with tap tempo (default: " => string modePrompt;
modePrompt + fmtInt(beatsPerLoop) => modePrompt;
modePrompt + " beats)\n[2] Free Mode - Record start/stop on keypress, any duration" => modePrompt;
printBlock(modePrompt);

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
    "✓ MEASURE MODE selected (" => string msg;
    msg + fmtInt(beatsPerLoop) => msg;
    msg + " beats per loop)" => msg;
    msg + "\n[t] Tap Tempo | [b] Set Beat Length | [r] Record loop | [p] Play/Stop | [o] Add Overdub | [u] Redo Last | [0-9] Toggle Loops | [q] Quit" => string menu;
    printBlock(menu);
    }
    else if (k == '2')
    {
        0 => measureMode;
        0 => modeSelected;
        printBlock("✓ FREE MODE selected\n[r] Start/Stop Recording | [p] Play/Stop | [o] Add Overdub | [u] Redo Last | [0-9] Toggle Loops | [q] Quit");
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
        if (!(measureMode && isRecording))
        {
            spork ~ recordLoop();
        }
    }
    else if (k == 'p')
    {
        if (isPlaying) 0 => isPlaying;
        else if (loopExists) spork ~ startPlayback();
        else printLine("Record first [r]");
    }
    else if (k == 'o')
    {
        spork ~ recordOverdub();
    }
    else if (k == 'u')
    {
        spork ~ redoLastOverdub();
    }
    else if (k >= '0' && k <= '9')
    {
        k - '0' => int loopNum;
        if (loopNum == 0)
        {
            if (loopExists && isPlaying)
            {
                !mainLoopActive => mainLoopActive;
                setMainLoopMonitor(mainLoopActive);
                if (mainLoopActive) printLine("Main loop ON");
                else printLine("Main loop OFF");
            }
        }
        else
        {
            loopNum - 1 => int overdubIndex;
            if (overdubIndex < overdubCount && isPlaying)
            {
                !overdubActive[overdubIndex] => overdubActive[overdubIndex];
                setOverdubMonitor(overdubIndex, overdubActive[overdubIndex]);
                if (overdubActive[overdubIndex])
                {
                    "Overdub " => string onMsg;
                    onMsg + fmtInt(loopNum) => onMsg;
                    onMsg + " ON" => onMsg;
                    printLine(onMsg);
                }
                else
                {
                    "Overdub " => string offMsg;
                    offMsg + fmtInt(loopNum) => offMsg;
                    offMsg + " OFF" => offMsg;
                    printLine(offMsg);
                }
            }
        }
    }
    else if (k == 'q')
    {
        if (loopExists)
        {
            printBlock("Save final mix to WAV? [y/n]");
            kb => now;
            kb.getchar() => int answer;
            
            if (answer == 'y' || answer == 'Y')
            {
                printLine("Recording final mix...");
                
                if (isPlaying)
                {
                    printLine("Waiting for loop start...");
                    loopStart => now;
                }
                
                "final_mix.wav" => string filename;
                WvOut wout => blackhole;
                wout.wavFilename(filename);
                
                mainLoop => wout;
                for (0 => int i; i < overdubCount; i++)
                {
                    overdubPlayers[i] => wout;
                }
                
                if (!isPlaying)
                {
                    mainLoop.playPos(0::ms);
                    mainLoop.loopStart(0::ms);
                    mainLoop.loopEnd(loopLength);
                    mainLoop.loopEndRec(loopLength - 5::ms);
                    mainLoop.loop(1);
                    mainLoop.play(1);
                    setMainLoopMonitor(mainLoopActive);
                    for (0 => int i; i < overdubCount; i++)
                    {
                        overdubPlayers[i].playPos(0::ms);
                        overdubPlayers[i].loopStart(0::ms);
                        overdubPlayers[i].loopEnd(loopLength);
                        overdubPlayers[i].loopEndRec(loopLength - 5::ms);
                        overdubPlayers[i].loop(1);
                        overdubPlayers[i].play(1);
                        setOverdubMonitor(i, overdubActive[i]);
                    }
                }
                
                    printLine("Recording...");
                loopLength => now;
                
                wout.closeFile();
                    "✓ Saved as " => string msg;
                    msg + filename => msg;
                    printLine(msg);
            }
        }
        
        printLine("Loop station stopped. Bye!");
        me.exit();
    }
}
