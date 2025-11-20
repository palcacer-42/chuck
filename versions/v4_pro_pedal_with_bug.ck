// LOOPSTATION VERSION 4: PROFESSIONAL LOOP PEDAL BEHAVIOR
// State: Breakthrough - simultaneous record and playback for overdubs

// KEY INSIGHT:
// Professional loop pedals (Boss RC, TC Ditto) start PLAYBACK with RECORDING
// This eliminates ALL phase shift issues!

// CHANGES:
// - Default beat length changed from 5 to 4 (standard 4/4 time)
// - Audio device display improvements
// - CRITICAL: Overdubs now play while recording

/*
BREAKTHROUGH CODE - SIMULTANEOUS RECORD/PLAYBACK:

fun void recordOverdub()
{
    // Wait for loop start for perfect sync
    loopStart => now;
    
    1 => isOverdubbing;
    
    // Configure LiSa buffer for this overdub with exact loop length
    overdubPlayers[overdubCount].duration(loopLength);
    overdubPlayers[overdubCount].recPos(0::ms);
    overdubPlayers[overdubCount].recRamp(0::ms);
    overdubPlayers[overdubCount].loopStart(0::ms);
    overdubPlayers[overdubCount].loopEnd(loopLength);
    overdubPlayers[overdubCount].loopEndRec(loopLength - 5::ms);
    overdubPlayers[overdubCount].loop(1);  // Enable looping BEFORE recording
    
    // Start recording at exact loop boundary
    overdubPlayers[overdubCount].record(1);
    
    // ALSO start playback immediately in record mode
    // This will play what's being recorded with one loop delay
    overdubPlayers[overdubCount].playPos(0::ms);
    overdubPlayers[overdubCount].play(1);
    
    // Record for exactly one loop length (sample-accurate)
    loopLength => now;
    
    // Stop recording - playback continues seamlessly
    overdubPlayers[overdubCount].record(0);
    
    0 => isOverdubbing;
    
    overdubCount++;
}
*/

/*
HOW IT WORKS:
1. Recording starts at position 0
2. Playback also starts at position 0 (buffer is empty)
3. Both record and playback pointers advance together through the loop
4. After one loop cycle, playback plays what was just recorded
5. Recording stops, playback continues
6. Perfect synchronization - zero phase shift!
*/

/*
INITIAL LOOP RECORDING - WITH LOOPING ENABLED:

fun void recordMeasureLoop()
{
    beatsPerLoop * beatDur => loopLength;
    
    // Configure LiSa buffer for main loop with looping enabled from start
    mainLoop.duration(loopLength);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(0::ms);
    mainLoop.loopStart(0::ms);
    mainLoop.loopEnd(loopLength);
    mainLoop.loopEndRec(loopLength - 5::ms);
    mainLoop.loop(1);  // Loop enabled during recording
    
    // Start recording
    mainLoop.record(1);

    // Record exactly beatsPerLoop beats
    for (0 => int beat; beat < beatsPerLoop; beat++)
    {
        for (0 => int sub; sub < 4; sub++)
        {
            showLED(beat * 4 + sub);
            beatDur / 4.0 => now;
        }
    }

    // Stop recording
    mainLoop.record(0);
    
    startPlayback();
}
*/

// PROBLEM WITH v4: loop(1) enabled during INITIAL recording caused noise!
// USER FEEDBACK: "something terrible happened! now is just recording noise"
// ISSUE: Main loop was looping back to 0 while still recording the first pass
