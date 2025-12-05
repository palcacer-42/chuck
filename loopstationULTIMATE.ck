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

// MIDI Controller Setup for Akai APC Mini (Optional)
MidiIn midiIn;
MidiMsg midiMsg;
MidiOut midiOut;
0 => int useMidi;

// APC Mini fader CC numbers (48-55 for the 8 vertical faders)
[48, 49, 50, 51, 52, 53, 54, 55] @=> int faderCC[];

// APC Mini button notes (8x8 grid, row 0=top, row 7=bottom)
// Each array has 8 elements, one per column
[8, 9, 10, 11, 12, 13, 14, 15] @=> int row1Buttons[];      // Row 1: Track on/off (mute)
[40, 41, 42, 43, 44, 45, 46, 47] @=> int row5Buttons[];    // Row 5: Speed control
[32, 33, 34, 35, 36, 37, 38, 39] @=> int row4Buttons[];    // Row 4: Reverse toggle
[48, 49, 50, 51, 52, 53, 54, 55] @=> int panButtons[];     // Row 6: Pan mode
[56, 57, 58, 59, 60, 61, 62, 63] @=> int volumeButtons[];  // Row 7: Volume mode

// APC Mini LED colors (velocity values for note messages)
1 => int LED_GREEN;
5 => int LED_YELLOW;
3 => int LED_RED;
0 => int LED_OFF;

// Track color assignments (repeating pattern: green, yellow, red)
[LED_GREEN, LED_YELLOW, LED_RED, LED_GREEN, LED_YELLOW, LED_RED, LED_GREEN, LED_YELLOW] @=> int trackColors[];

// Track control modes: 0 = volume, 1 = pan
int trackMode[8];     // Mode for each of the 8 tracks
float trackPan[8];    // Pan values for each track (-1.0 to 1.0)
int ledFlashState;    // Global flash state (0 or 1) for all flashing LEDs

// Initialize all tracks to volume mode with center pan
for (0 => int i; i < 8; i++) 
{
    0 => trackMode[i];
    0.0 => trackPan[i];
}

// LED flasher thread - toggles flash state every 250ms
fun void ledFlasher()
{
    while (true)
    {
        250::ms => now;
        !ledFlashState => ledFlashState;
        
        // Update all track LEDs with new flash state
        if (useMidi)
        {
            for (0 => int i; i < 8; i++)
            {
                updateTrackLEDs(i);
            }
        }
    }
}

adc => Gain input => blackhole;
input.gain(0.8);

// Main loop using LiSa buffer with volume control and pan
LiSa mainLoop => Gain masterGain => Pan2 masterPan => dac;
adc => mainLoop;
mainLoop.gain(0.9);
masterGain.gain(0.9);  // Master volume control
masterPan.pan(0.0);    // Center pan (-1.0 = left, 0.0 = center, 1.0 = right)
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
4 => int beatsPerLoop;  // Configurable beat length (default 4)
16 => int ledCount;  // Will be updated based on beatsPerLoop

// Mode selection: 0 = free mode, 1 = measure mode
0 => int measureMode;
// How the initial loop was actually recorded: 0 = measure, 1 = free
0 => int freeLoop;

// Multiple overdubs support
LiSa overdubPlayers[10]; // Support up to 10 overdubs
Pan2 overdubPan[10];     // Pan control for each overdub
0 => int overdubCount;
int overdubActive[10]; // Track which overdubs are active
1 => int mainLoopActive; // Track if main loop is active

// Initialize overdub players with LiSa buffers and pan
for (0 => int i; i < 10; i++)
{
    adc => overdubPlayers[i] => overdubPan[i] => dac;
    overdubPlayers[i].gain(0.9);
    overdubPlayers[i].maxVoices(1);
    overdubPan[i].pan(0.0);  // Center pan initially
    1 => overdubActive[i]; // Start active by default
}

Event loopStart;

0 => int tapCount;
time lastTap;
time recordStart;  // Track when recording started

// Status message for three-line display
"" => string statusMessage;
0 => int displayInitialized;

// Effect controls
1.0 => float mainSpeed;      // Speed/pitch control (0.5 = half speed, 2.0 = double)
1 => int mainReverse;        // 1 = forward, -1 = reverse
0.9 => float mainVolume;     // Master volume (0.0 to 1.0)
0.0 => float mainPan;        // Pan position (-1.0 = left, 0.0 = center, 1.0 = right)

// Individual track volumes, speeds, and reverse
0.9 => float mainTrackVolume;     // Main loop volume
float overdubVolumes[10];         // Overdub track volumes
float overdubSpeeds[10];          // Overdub speeds (per track)
int overdubReverse[10];           // Overdub reverse (per track)

// Initialize overdub effects
for (0 => int i; i < 10; i++)
{
    0.9 => overdubVolumes[i];
    1.0 => overdubSpeeds[i];      // Normal speed
    1 => overdubReverse[i];       // Forward
}

0 => int selectedTrack;      // Currently selected track (0 = main, 1-10 = overdubs)

// ------------------------------------------------------
// LED RING: EXACT ○ and ●
// ------------------------------------------------------

// --- show LED ring in console with three stable lines ---
fun void showLED(int pos)
{
    // Initialize display with 3 blank lines on first call
    if (!displayInitialized)
    {
        chout <= "\n\n\n";  // Create 3 lines
        1 => displayInitialized;
    }
    
    // Build LED ring (Line 3)
    "" => string leds;
    for (0 => int i; i < ledCount; i++)
    {
        if (i == pos) leds + "●" => leds;
        else leds + "○" => leds;
        
        // Add spacing every beat (4 subdivisions per beat) for readability
        if ((i + 1) % 4 == 0 && i < ledCount - 1) leds + " " => leds;
    }
    
    // Build track status (Line 2) with effects display
    "Tracks: " => string tracks;
    
    // Main loop (track 0)
    if (selectedTrack == 0) tracks + "\033[1m" => tracks;  // Bold for selected
    tracks + "[0:" => tracks;
    if (mainLoopActive) tracks + "●" => tracks;
    else tracks + "○" => tracks;
    
    // Show effects for main loop
    "" => string fx;
    if (mainSpeed != 1.0) {
        if (fx != "") fx + "," => fx;
        fx + "spd:" => fx;
        Math.floor(mainSpeed * 10 + 0.5) / 10.0 => float roundedSpeed;
        fx + roundedSpeed => fx;
    }
    if (mainReverse == -1) {
        if (fx != "") fx + "," => fx;
        fx + "rev" => fx;
    }
    if (fx != "") tracks + " " + fx => tracks;
    tracks + "]" => tracks;
    if (selectedTrack == 0) tracks + "\033[0m" => tracks;  // Reset bold
    
    // Overdub tracks
    for (0 => int i; i < overdubCount; i++)
    {
        tracks + " " => tracks;
        if (selectedTrack == i + 1) tracks + "\033[1m" => tracks;  // Bold for selected
        tracks + "[" + (i+1) + ":" => tracks;
        if (overdubActive[i]) tracks + "●" => tracks;
        else tracks + "○" => tracks;
        tracks + "]" => tracks;
        if (selectedTrack == i + 1) tracks + "\033[0m" => tracks;  // Reset bold
    }
    
    // Pad lines to clear previous content (fixed width 80 chars)
    statusMessage => string msg;
    tracks => string trk;
    leds => string led;
    while (msg.length() < 80) msg + " " => msg;
    while (trk.length() < 80) trk + " " => trk;
    while (led.length() < 80) led + " " => led;
    
    // Move cursor up 3 lines to start, print all 3 lines, cursor stays at end
    chout <= "\033[3A";           // Move up 3 lines
    chout <= "\r" <= msg;         // Line 1: Status (no newline, cursor at end of line 1)
    chout <= "\n\r" <= trk;       // Line 2: Tracks (newline first, then overwrite)
    chout <= "\n\r" <= led;       // Line 3: LEDs (newline first, then overwrite)
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
    0 => freeLoop; // this loop is measure-based

    // If playback is active, wait for the next loop to start for sync
    if (isPlaying)
    {
        "Waiting for next loop..." => statusMessage;
        showLED(0);
        loopStart => now;
        "RECORDING " + beatsPerLoop + "-beat loop..." => statusMessage;
        showLED(0);
    }
    else
    {
        // Only use metronome countdown when recording the first loop (one extra beat)
        "RECORDING " + (beatsPerLoop + 1) + " beats with countdown..." => statusMessage;
        showLED(0);
        
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
    "LOOP RECORDED!" => statusMessage;
    showLED(0);
    
    // Start playback directly (not spawned - we're already in a spawned shred)
    startPlayback();
}

// Start free recording
fun void startFreeRecording()
{
    1 => isRecording;
    1 => freeLoop; // this loop is free-mode based
    now => recordStart;
    
    "● RECORDING... Press [r] to stop" => statusMessage;
    showLED(0);
    
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
    mainLoop.loopEndRec(loopLength - 5::ms);  // 5ms crossfade for smooth loop
    
    0 => isRecording;
    1 => loopExists;
    "○ LOOP RECORDED! " + (loopLength/second) + " sec" => statusMessage;
    showLED(0);
    
    // Update MIDI LEDs (main loop is now available)
    updateTrackLEDs(0);
    
    // Start playback
    startPlayback();
}

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
                        "Record first with Button 1" => statusMessage;
                        showLED(0);
                    }
                }
            }
        }
    }
}

// Function to open Akai APC Mini MIDI controller (Optional)
fun int openMidiController()
{
    // Try to find and open APC Mini for input and output
    for (0 => int i; i < 8; i++)  // Check first 8 MIDI devices
    {
        if (midiIn.open(i))
        {
            // Check if it's an APC Mini (name contains "APC")
            if (midiIn.name().find("APC") >= 0 || midiIn.name().find("apc") >= 0)
            {
                // Also open MIDI output for LED control
                midiOut.open(i);
                <<< "✓ MIDI Controller connected:", midiIn.name() >>>;
                return 1;
            }
            else
            {
                // Not APC Mini, close and try next
                // Note: ChucK doesn't have midiIn.close(), but opening another will close previous
            }
        }
    }
    <<< "APC Mini not found - keyboard controls only" >>>;
    return 0;
}

// Function to set LED color on APC Mini button
fun void setButtonLED(int note, int color)
{
    if (!useMidi) return;
    
    midiMsg.data1 => int oldData1;
    midiMsg.data2 => int oldData2;
    midiMsg.data3 => int oldData3;
    
    0x90 => midiMsg.data1;  // Note On message
    note => midiMsg.data2;   // Note number
    color => midiMsg.data3;  // Velocity = color
    midiOut.send(midiMsg);
    
    oldData1 => midiMsg.data1;
    oldData2 => midiMsg.data2;
    oldData3 => midiMsg.data3;
}

// Function to update LEDs for a specific track
fun void updateTrackLEDs(int trackIndex)
{
    if (!useMidi) return;
    
    // Get the color for this track
    trackColors[trackIndex] => int trackColor;
    
    if (trackIndex == 0)
    {
        // Main loop - show buttons if loop exists
        if (loopExists)
        {
            // Volume and Pan buttons (rows 7 and 6)
            if (trackMode[0] == 0) // Volume mode active
            {
                // Volume flashes, Pan stays solid
                if (ledFlashState) setButtonLED(volumeButtons[0], trackColor);
                else setButtonLED(volumeButtons[0], LED_OFF);
                setButtonLED(panButtons[0], trackColor);  // Solid
            }
            else // Pan mode active
            {
                // Pan flashes, Volume stays solid
                setButtonLED(volumeButtons[0], trackColor);  // Solid
                if (ledFlashState) setButtonLED(panButtons[0], trackColor);
                else setButtonLED(panButtons[0], LED_OFF);
            }
            
            // Speed control button (row 5) - show if speed is not 1.0
            if (mainSpeed != 1.0)
            {
                if (ledFlashState) setButtonLED(row5Buttons[0], trackColor);
                else setButtonLED(row5Buttons[0], LED_OFF);
            }
            else
            {
                setButtonLED(row5Buttons[0], trackColor);  // Solid when at normal speed
            }
            
            // Reverse button (row 4) - flash when reverse is active
            if (mainReverse == -1)
            {
                if (ledFlashState) setButtonLED(row4Buttons[0], trackColor);
                else setButtonLED(row4Buttons[0], LED_OFF);
            }
            else
            {
                setButtonLED(row4Buttons[0], trackColor);  // Solid when forward
            }
            
            // Track on/off button (row 3) - lit when track is active
            if (mainLoopActive)
            {
                setButtonLED(row1Buttons[0], trackColor);  // Solid when on
            }
            else
            {
                setButtonLED(row1Buttons[0], LED_OFF);  // Off when muted
            }
        }
        else
        {
            // No loop - turn off all buttons
            setButtonLED(volumeButtons[0], LED_OFF);
            setButtonLED(panButtons[0], LED_OFF);
            setButtonLED(row5Buttons[0], LED_OFF);
            setButtonLED(row4Buttons[0], LED_OFF);
            setButtonLED(row1Buttons[0], LED_OFF);
        }
    }
    else if (trackIndex - 1 < overdubCount)
    {
        // Overdub track - show all buttons
        if (trackMode[trackIndex] == 0) // Volume mode active
        {
            // Volume flashes, Pan stays solid
            if (ledFlashState) setButtonLED(volumeButtons[trackIndex], trackColor);
            else setButtonLED(volumeButtons[trackIndex], LED_OFF);
            setButtonLED(panButtons[trackIndex], trackColor);  // Solid
        }
        else // Pan mode active
        {
            // Pan flashes, Volume stays solid
            setButtonLED(volumeButtons[trackIndex], trackColor);  // Solid
            if (ledFlashState) setButtonLED(panButtons[trackIndex], trackColor);
            else setButtonLED(panButtons[trackIndex], LED_OFF);
        }
        
        // Speed control button (row 5) - show if speed is not 1.0
        trackIndex - 1 => int odIdx;
        if (overdubSpeeds[odIdx] != 1.0)
        {
            if (ledFlashState) setButtonLED(row5Buttons[trackIndex], trackColor);
            else setButtonLED(row5Buttons[trackIndex], LED_OFF);
        }
        else
        {
            setButtonLED(row5Buttons[trackIndex], trackColor);  // Solid when at normal speed
        }
        
        // Reverse button (row 4) - flash when reverse is active
        if (overdubReverse[odIdx] == -1)
        {
            if (ledFlashState) setButtonLED(row4Buttons[trackIndex], trackColor);
            else setButtonLED(row4Buttons[trackIndex], LED_OFF);
        }
        else
        {
            setButtonLED(row4Buttons[trackIndex], trackColor);  // Solid when forward
        }
        
        // Track on/off button (row 3) - lit when track is active
        if (overdubActive[odIdx])
        {
            setButtonLED(row1Buttons[trackIndex], trackColor);  // Solid when on
        }
        else
        {
            setButtonLED(row1Buttons[trackIndex], LED_OFF);  // Off when muted
        }
    }
    else
    {
        // Track doesn't exist yet - turn off all LEDs
        setButtonLED(volumeButtons[trackIndex], LED_OFF);
        setButtonLED(panButtons[trackIndex], LED_OFF);
        setButtonLED(row5Buttons[trackIndex], LED_OFF);
        setButtonLED(row4Buttons[trackIndex], LED_OFF);
        setButtonLED(row1Buttons[trackIndex], LED_OFF);
    }
}

// Function to initialize all LEDs (turn off unused, set active tracks)
fun void initializeAllLEDs()
{
    if (!useMidi) return;
    
    // Update LEDs for all 8 possible tracks
    for (0 => int i; i < 8; i++)
    {
        updateTrackLEDs(i);
    }
}

// MIDI listener thread for APC Mini faders and buttons
fun void midiListener()
{
    while (true)
    {
        midiIn => now;
        
        while (midiIn.recv(midiMsg))
        {
            // Check if it's a Control Change message (faders)
            if ((midiMsg.data1 & 0xF0) == 0xB0)
            {
                midiMsg.data2 => int ccNumber;  // CC number
                midiMsg.data3 => int ccValue;   // CC value (0-127)
                
                // Check which fader was moved
                for (0 => int i; i < faderCC.size(); i++)
                {
                    if (ccNumber == faderCC[i])
                    {
                        // Check if this track exists
                        if (i == 0 && !loopExists) break;
                        if (i > 0 && i - 1 >= overdubCount) break;
                        
                        // Process based on current mode
                        if (trackMode[i] == 0) // Volume mode
                        {
                            ccValue / 127.0 => float volume;
                            
                            if (i == 0)
                            {
                                volume => mainTrackVolume;
                                if (isPlaying && mainLoopActive) mainLoop.gain(mainTrackVolume);
                            }
                            else
                            {
                                i - 1 => int odIdx;
                                volume => overdubVolumes[odIdx];
                                if (isPlaying && overdubActive[odIdx]) 
                                {
                                    overdubPlayers[odIdx].gain(overdubVolumes[odIdx]);
                                }
                            }
                        }
                        else // Pan mode
                        {
                            // Convert MIDI value (0-127) to pan (-1.0 to 1.0)
                            (ccValue - 63.5) / 63.5 => float pan;
                            pan => trackPan[i];
                            
                            if (i == 0)
                            {
                                masterPan.pan(pan);
                            }
                            else
                            {
                                i - 1 => int odIdx;
                                overdubPan[odIdx].pan(pan);
                            }
                        }
                        break;
                    }
                }
            }
            // Check if it's a Note On message (button press)
            else if ((midiMsg.data1 & 0xF0) == 0x90 && midiMsg.data3 > 0)
            {
                midiMsg.data2 => int note;
                
                // Check if it's a volume or pan button
                for (0 => int i; i < 8; i++)
                {
                    // Volume button pressed
                    if (note == volumeButtons[i])
                    {
                        // Check if track exists
                        if (i == 0 && loopExists)
                        {
                            0 => trackMode[i];  // Set to volume mode
                            updateTrackLEDs(i);
                        }
                        else if (i > 0 && i - 1 < overdubCount)
                        {
                            0 => trackMode[i];  // Set to volume mode
                            updateTrackLEDs(i);
                        }
                        break;
                    }
                    // Pan button pressed
                    else if (note == panButtons[i])
                    {
                        // Check if track exists
                        if (i == 0 && loopExists)
                        {
                            1 => trackMode[i];  // Set to pan mode
                            updateTrackLEDs(i);
                        }
                        else if (i > 0 && i - 1 < overdubCount)
                        {
                            1 => trackMode[i];  // Set to pan mode
                            updateTrackLEDs(i);
                        }
                        break;
                    }
                    // Speed button pressed
                    else if (note == row5Buttons[i])
                    {
                        if (i == 0 && loopExists)
                        {
                            // Main loop speed
                            if (mainSpeed == 1.0) 1.5 => mainSpeed;
                            else if (mainSpeed == 1.5) 2.0 => mainSpeed;
                            else if (mainSpeed == 2.0) 0.5 => mainSpeed;
                            else 1.0 => mainSpeed;
                            
                            if (isPlaying) mainLoop.rate(mainSpeed * mainReverse);
                            updateTrackLEDs(0);
                        }
                        else if (i > 0 && i - 1 < overdubCount)
                        {
                            // Overdub speed
                            i - 1 => int odIdx;
                            if (overdubSpeeds[odIdx] == 1.0) 1.5 => overdubSpeeds[odIdx];
                            else if (overdubSpeeds[odIdx] == 1.5) 2.0 => overdubSpeeds[odIdx];
                            else if (overdubSpeeds[odIdx] == 2.0) 0.5 => overdubSpeeds[odIdx];
                            else 1.0 => overdubSpeeds[odIdx];
                            
                            if (isPlaying) overdubPlayers[odIdx].rate(overdubSpeeds[odIdx] * overdubReverse[odIdx]);
                            updateTrackLEDs(i);
                        }
                        break;
                    }
                    // Reverse button pressed
                    else if (note == row4Buttons[i])
                    {
                        if (i == 0 && loopExists)
                        {
                            // Main loop reverse
                            -1 * mainReverse => mainReverse;
                            if (isPlaying) mainLoop.rate(mainSpeed * mainReverse);
                            updateTrackLEDs(0);
                        }
                        else if (i > 0 && i - 1 < overdubCount)
                        {
                            // Overdub reverse
                            i - 1 => int odIdx;
                            -1 * overdubReverse[odIdx] => overdubReverse[odIdx];
                            if (isPlaying) overdubPlayers[odIdx].rate(overdubSpeeds[odIdx] * overdubReverse[odIdx]);
                            updateTrackLEDs(i);
                        }
                        break;
                    }
                    // Track on/off button pressed (row 3)
                    else if (note == row1Buttons[i])
                    {
                        if (i == 0 && loopExists)
                        {
                            // Toggle main loop on/off
                            !mainLoopActive => mainLoopActive;
                            if (isPlaying)
                            {
                                if (mainLoopActive) mainLoop.gain(mainTrackVolume);
                                else mainLoop.gain(0.0);
                            }
                            updateTrackLEDs(0);
                        }
                        else if (i > 0 && i - 1 < overdubCount)
                        {
                            // Toggle overdub on/off
                            i - 1 => int odIdx;
                            !overdubActive[odIdx] => overdubActive[odIdx];
                            if (isPlaying)
                            {
                                if (overdubActive[odIdx]) overdubPlayers[odIdx].gain(overdubVolumes[odIdx]);
                                else overdubPlayers[odIdx].gain(0.0);
                            }
                            updateTrackLEDs(i);
                        }
                        break;
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

    // CRITICAL: Start all loops at EXACTLY the same time with same settings
    // Configure main loop
    mainLoop.playPos(0::ms);
    mainLoop.loopStart(0::ms);
    mainLoop.loopEnd(loopLength);
    mainLoop.loopEndRec(loopLength - 5::ms);  // Start crossfade 5ms before end
    mainLoop.loop(1);  // Enable looping
    mainLoop.rate(mainSpeed * mainReverse);  // Apply speed and reverse
    if (mainLoopActive) mainLoop.gain(mainTrackVolume);
    else mainLoop.gain(0.0);

    // Configure all existing overdubs (but don't start yet)
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].playPos(0::ms);
        overdubPlayers[i].loopStart(0::ms);
        overdubPlayers[i].loopEnd(loopLength);
        overdubPlayers[i].loopEndRec(loopLength - 5::ms);  // 5ms crossfade
        overdubPlayers[i].loop(1);
        overdubPlayers[i].rate(overdubSpeeds[i] * overdubReverse[i]);  // Apply speed and reverse
        if (overdubActive[i]) overdubPlayers[i].gain(overdubVolumes[i]);
        else overdubPlayers[i].gain(0.0);
    }
    
    // NOW start everything at once for perfect sync
    mainLoop.play(1);
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].play(1);
    }

    loopStart.broadcast();

    "PLAYING..." => statusMessage;
    showLED(0);

    while (isPlaying && loopExists)
    {
        now => time loopStartTime;
        1 => int stepDone;
        
        // Calculate actual loop duration accounting for speed/rate
        loopLength / Math.fabs(mainSpeed * mainReverse) => dur actualLoopDur;
        
        if (!freeLoop)
        {
            // MEASURE MODE: Sample-accurate LED ring animation
            for (0 => int s; s < ledCount; s++)
            {
                if (!isPlaying)
                {
                    0 => stepDone;
                    break;
                }
                showLED(s);
                // Wait until exact time position (sample-accurate, accounting for rate)
                loopStartTime + (s + 1) * actualLoopDur / ledCount => time nextTime;
                nextTime - now => now;
            }
        }
        else
        {
            // FREE MODE: Sample-accurate LED animation
            for (0 => int s; s < ledCount; s++)
            {
                if (!isPlaying)
                {
                    0 => stepDone;
                    break;
                }
                showLED(s);
                // Wait until exact time position (sample-accurate, accounting for rate)
                loopStartTime + (s + 1) * actualLoopDur / ledCount => time nextTime;
                nextTime - now => now;
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
        "Play loop first [p]" => statusMessage;
        showLED(0);
        return;
    }

    if (isOverdubbing)
    {
        "Overdub in progress..." => statusMessage;
        showLED(0);
        return;
    }

    if (overdubCount >= 10)
    {
        "Max overdubs (10) reached!" => statusMessage;
        showLED(0);
        return;
    }

    // Both modes: Wait for loop start for sync
    "OVERDUB " + (overdubCount + 1) + " - waiting..." => statusMessage;
    showLED(0);
    loopStart => now;
    
    1 => isOverdubbing;
    "OVERDUB " + (overdubCount + 1) + " RECORDING..." => statusMessage;
    showLED(0);
    
    // Configure LiSa buffer for this overdub WITH LOOPING ENABLED
    overdubPlayers[overdubCount].duration(loopLength);
    overdubPlayers[overdubCount].recPos(0::ms);
    overdubPlayers[overdubCount].recRamp(0::ms);  // No ramp for precise timing
    overdubPlayers[overdubCount].loopStart(0::ms);
    overdubPlayers[overdubCount].loopEnd(loopLength);
    overdubPlayers[overdubCount].loopEndRec(loopLength - 5::ms);  // 5ms crossfade
    overdubPlayers[overdubCount].loop(1);  // Enable looping DURING recording
    overdubPlayers[overdubCount].rate(1.0);  // Always normal rate for sync
    overdubPlayers[overdubCount].gain(overdubVolumes[overdubCount]);
    
    // Start recording
    overdubPlayers[overdubCount].record(1);
    
    // Start playback IMMEDIATELY (play while recording for zero latency)
    overdubPlayers[overdubCount].playPos(0::ms);
    overdubPlayers[overdubCount].play(1);
    
    // Record for exactly one loop length
    loopLength => now;
    
    // Stop recording - playback continues automatically
    overdubPlayers[overdubCount].record(0);
    
    0 => isOverdubbing;
    
    // Mark as active
    1 => overdubActive[overdubCount];
    
    overdubCount++;
    "OVERDUB " + overdubCount + " DONE! Total: " + overdubCount => statusMessage;
    showLED(0);
    
    // Update MIDI LEDs (new overdub track is now available)
    updateTrackLEDs(overdubCount);  // overdubCount already incremented, so this is the new track
}

// Undo the last overdub (remove it completely)
fun void undoLastOverdub()
{
    if (!loopExists)
    {
        "No loop exists" => statusMessage;
        showLED(0);
        return;
    }

    if (overdubCount == 0)
    {
        "No overdub to undo" => statusMessage;
        showLED(0);
        return;
    }

    // Decrement count FIRST so other functions see correct state immediately
    overdubCount--;
    
    // Now get the index of what WAS the last overdub
    overdubCount => int lastIndex;

    // Stop playback immediately - this is audible
    overdubPlayers[lastIndex].play(0);
    overdubPlayers[lastIndex].record(0);
    overdubPlayers[lastIndex].loop(0);
    overdubPlayers[lastIndex].gain(0.0);  // Mute it

    // Clear its buffer
    overdubPlayers[lastIndex].duration(loopLength);

    // Mark as inactive (will be skipped on next playback restart)
    0 => overdubActive[lastIndex];

    "UNDID overdub " + (lastIndex + 1) + " - Remaining: " + overdubCount => statusMessage;
    showLED(0);
}

// Erase everything and start fresh
fun void eraseAll()
{
    if (!loopExists)
    {
        "Nothing to erase" => statusMessage;
        showLED(0);
        return;
    }

    // Stop playback FIRST
    0 => isPlaying;
    0 => isRecording;
    0 => isOverdubbing;
    
    // Give the playback loop time to exit cleanly
    10::ms => now;
    
    // Stop and clear main loop completely
    mainLoop.play(0);
    mainLoop.record(0);
    mainLoop.loop(0);
    mainLoop.gain(0.0);  // Mute it completely during clearing
    
    // Clear main loop buffer by resetting duration
    1::second => dur tempDur;
    mainLoop.duration(tempDur);
    mainLoop.clear();
    
    // Stop and clear all overdubs completely
    for (0 => int i; i < 10; i++)
    {
        overdubPlayers[i].play(0);
        overdubPlayers[i].record(0);
        overdubPlayers[i].loop(0);
        overdubPlayers[i].gain(0.0);  // Mute completely
        
        // Clear buffer
        overdubPlayers[i].duration(tempDur);
        overdubPlayers[i].clear();
        
        1 => overdubActive[i];
    }
    
    // Wait a bit to ensure everything stopped
    10::ms => now;
    
    // Restore gains after clearing
    mainLoop.gain(0.9);
    for (0 => int i; i < 10; i++)
    {
        overdubPlayers[i].gain(0.9);
    }
    
    // Reset state
    0 => loopExists;
    0 => overdubCount;
    1 => mainLoopActive;
    0 => freeLoop;
    
    "ALL CLEARED!" => statusMessage;
    showLED(0);
    
    // Turn off all MIDI LEDs
    initializeAllLEDs();
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

// Try to connect MIDI Controller (APC Mini)
<<< "\nAttempting to connect Akai APC Mini..." >>>;
if (openMidiController())
{
    1 => useMidi;
    spork ~ midiListener();
    spork ~ ledFlasher();  // Start LED flasher thread
    initializeAllLEDs();  // Initialize LED display
    <<< "✓ APC Mini ready!" >>>;
    <<< "  Each column = one track (color: Green→Yellow→Red→repeat)" >>>;
    <<< "  Faders control volume/pan (switch with row 7/6 buttons)" >>>;
    <<< "  Row 1: Track On/Off | Row 4: Reverse | Row 5: Speed" >>>;
    <<< "  Row 6: Pan mode | Row 7: Volume mode" >>>;
    <<< "  Flashing = active, Solid = available" >>>;
}
else
{
    <<< "APC Mini not found - using keyboard controls only" >>>;
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
    
    while (kb.more())
    {
        kb.getchar() => int k;
        
        if (k == '1')
        {
            1 => measureMode;
            0 => modeSelected;
            <<< "\n✓ MEASURE MODE selected (", beatsPerLoop, "beats per loop)" >>>;
            <<< "RECORDING: [t] Tap Tempo | [b] Set Beat Length | [r] Record | [o] Overdub" >>>;
            <<< "PLAYBACK: [p] Play/Stop | [u] Undo | [e] Erase All | [0-9] Select/Toggle Track" >>>;
            <<< "EFFECTS: [+/-/=] Speed | [v] Reverse | [{] [}] Track Vol | [[] []] Master Vol | [<] [>] Pan" >>>;
            <<< "[q] Quit | [x/ESC] Emergency Stop" >>>;
            break;  // Exit inner loop
        }
        else if (k == '2')
        {
            0 => measureMode;
            0 => modeSelected;
            <<< "\n✓ FREE MODE selected" >>>;
            <<< "RECORDING: [r] Start/Stop Recording | [o] Overdub" >>>;
            <<< "PLAYBACK: [p] Play/Stop | [u] Undo | [e] Erase All | [0-9] Select/Toggle Track" >>>;
            <<< "EFFECTS: [+/-/=] Speed | [v] Reverse | [{] [}] Track Vol | [[] []] Master Vol | [<] [>] Pan" >>>;
            <<< "[q] Quit | [x/ESC] Emergency Stop" >>>;
            break;  // Exit inner loop
        }
        else if (k == 'r')
        {
            // If user presses 'r' before choosing mode, treat it exactly like pressing '2'
            // This ensures identical behavior to manual free mode selection
            0 => measureMode;
            0 => modeSelected;
            <<< "\n✓ FREE MODE auto-selected (recording started)" >>>;
            <<< "RECORDING: [r] Start/Stop Recording | [o] Overdub" >>>;
            <<< "PLAYBACK: [p] Play/Stop | [u] Undo | [e] Erase All | [0-9] Select/Toggle Track" >>>;
            <<< "EFFECTS: [+/-/=] Speed | [v] Reverse | [{] [}] Track Vol | [[] []] Master Vol | [<] [>] Pan" >>>;
            <<< "[q] Quit | [x/ESC] Emergency Stop" >>>;
            // Start recording after mode is properly set
            spork ~ recordLoop();
            break;  // Exit inner loop
        }
    }
}

// Small delay to ensure clean transition
1::ms => now;

while (true)
{
    // Use a timeout so Ctrl+C can work properly
    kb => now;
    
    // Process all available keypresses
    while (kb.more())
    {
        kb.getchar() => int k;

    if (k == 't' && !freeLoop) spork ~ tapTempo();
    else if (k == 'b' && !freeLoop) setBeatLength();
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
        else {
            "Record first [r]" => statusMessage;
            showLED(0);
        }
    }
    else if (k == 'o')
    {
        spork ~ recordOverdub();
    }
    else if (k == 'u')
    {
        spork ~ undoLastOverdub();
    }
    else if (k == 'e')
    {
        eraseAll();
    }
    // Speed controls
    else if (k == '+')
    {
        mainSpeed * 1.1 => mainSpeed;
        if (mainSpeed > 2.0) 2.0 => mainSpeed;
        if (isPlaying) mainLoop.rate(mainSpeed * mainReverse);
        "Speed: " + mainSpeed => statusMessage;
        showLED(0);
    }
    else if (k == '-')
    {
        mainSpeed * 0.9 => mainSpeed;
        if (mainSpeed < 0.5) 0.5 => mainSpeed;
        if (isPlaying) mainLoop.rate(mainSpeed * mainReverse);
        "Speed: " + mainSpeed => statusMessage;
        showLED(0);
    }
    else if (k == '=')
    {
        1.0 => mainSpeed;
        if (isPlaying) mainLoop.rate(mainSpeed * mainReverse);
        "Speed: 1.0 (reset)" => statusMessage;
        showLED(0);
    }
    // Reverse toggle
    else if (k == 'v')
    {
        -1 * mainReverse => mainReverse;
        if (isPlaying) mainLoop.rate(mainSpeed * mainReverse);
        if (mainReverse == -1) "REVERSE ON" => statusMessage;
        else "REVERSE OFF" => statusMessage;
        showLED(0);
    }
    // Volume controls
    else if (k == ']')
    {
        mainVolume + 0.1 => mainVolume;
        if (mainVolume > 1.0) 1.0 => mainVolume;
        masterGain.gain(mainVolume);
        "Volume: " + mainVolume => statusMessage;
        showLED(0);
    }
    else if (k == '[')
    {
        mainVolume - 0.1 => mainVolume;
        if (mainVolume < 0.0) 0.0 => mainVolume;
        masterGain.gain(mainVolume);
        "Volume: " + mainVolume => statusMessage;
        showLED(0);
    }
    // Pan controls
    else if (k == '.')
    {
        mainPan + 0.1 => mainPan;
        if (mainPan > 1.0) 1.0 => mainPan;
        masterPan.pan(mainPan);
        if (mainPan > 0) "Pan: R" + mainPan => statusMessage;
        else if (mainPan < 0) "Pan: L" + (-mainPan) => statusMessage;
        else "Pan: Center" => statusMessage;
        showLED(0);
    }
    else if (k == ',')
    {
        mainPan - 0.1 => mainPan;
        if (mainPan < -1.0) -1.0 => mainPan;
        masterPan.pan(mainPan);
        if (mainPan > 0) "Pan: R" + mainPan => statusMessage;
        else if (mainPan < 0) "Pan: L" + (-mainPan) => statusMessage;
        else "Pan: Center" => statusMessage;
        showLED(0);
    }
    // Track volume controls (for selected track)
    else if (k == '}')
    {
        if (selectedTrack == 0)
        {
            mainTrackVolume + 0.1 => mainTrackVolume;
            if (mainTrackVolume > 1.0) 1.0 => mainTrackVolume;
            if (isPlaying && mainLoopActive) mainLoop.gain(mainTrackVolume);
            "Track 0 vol: " + mainTrackVolume => statusMessage;
        }
        else if (selectedTrack - 1 < overdubCount)
        {
            selectedTrack - 1 => int odIdx;
            overdubVolumes[odIdx] + 0.1 => overdubVolumes[odIdx];
            if (overdubVolumes[odIdx] > 1.0) 1.0 => overdubVolumes[odIdx];
            if (isPlaying && overdubActive[odIdx]) overdubPlayers[odIdx].gain(overdubVolumes[odIdx]);
            "Track " + selectedTrack + " vol: " + overdubVolumes[odIdx] => statusMessage;
        }
        showLED(0);
    }
    else if (k == '{')
    {
        if (selectedTrack == 0)
        {
            mainTrackVolume - 0.1 => mainTrackVolume;
            if (mainTrackVolume < 0.0) 0.0 => mainTrackVolume;
            if (isPlaying && mainLoopActive) mainLoop.gain(mainTrackVolume);
            "Track 0 vol: " + mainTrackVolume => statusMessage;
        }
        else if (selectedTrack - 1 < overdubCount)
        {
            selectedTrack - 1 => int odIdx;
            overdubVolumes[odIdx] - 0.1 => overdubVolumes[odIdx];
            if (overdubVolumes[odIdx] < 0.0) 0.0 => overdubVolumes[odIdx];
            if (isPlaying && overdubActive[odIdx]) overdubPlayers[odIdx].gain(overdubVolumes[odIdx]);
            "Track " + selectedTrack + " vol: " + overdubVolumes[odIdx] => statusMessage;
        }
        showLED(0);
    }
    else if (k == '/')
    {
        0.0 => mainPan;
        masterPan.pan(mainPan);
        "Pan: Center (reset)" => statusMessage;
        showLED(0);
    }
    else if (k == 'x' || k == 27)  // 'x' key or ESC for emergency stop
    {
        <<< "EMERGENCY STOP - Exiting..." >>>;
        me.exit();
    }
    // Toggle loops with number keys
    else if (k >= '0' && k <= '9')
    {
        k - '0' => int loopNum;
        loopNum => selectedTrack;  // Update selected track
        
        if (loopNum == 0)
        {
            // Toggle main loop
            if (loopExists && isPlaying)
            {
                !mainLoopActive => mainLoopActive;
                // Control via gain for instant mute/unmute without sync issues
                if (mainLoopActive) mainLoop.gain(mainTrackVolume);
                else mainLoop.gain(0.0);
                if (mainLoopActive) "Main loop ON" => statusMessage;
                else "Main loop OFF" => statusMessage;
                showLED(0);
            }
        }
        else
        {
            loopNum - 1 => int overdubIndex;
            if (overdubIndex < overdubCount && isPlaying)
            {
                !overdubActive[overdubIndex] => overdubActive[overdubIndex];
                // Control via gain for instant mute/unmute without sync issues
                if (overdubActive[overdubIndex]) overdubPlayers[overdubIndex].gain(overdubVolumes[overdubIndex]);
                else overdubPlayers[overdubIndex].gain(0.0);
                if (overdubActive[overdubIndex]) "Overdub " + loopNum + " ON" => statusMessage;
                else "Overdub " + loopNum + " OFF" => statusMessage;
                showLED(0);
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
    }  // End of while (kb.more())
}


