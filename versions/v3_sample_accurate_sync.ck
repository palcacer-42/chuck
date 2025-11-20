// LOOPSTATION VERSION 3: SAMPLE-ACCURATE SYNCHRONIZATION
// State: Comprehensive timing refinement for free mode

// IMPROVEMENTS:
// - Sample-accurate recording timing
// - Precise loop length capture
// - Enhanced playback synchronization
// - Better command ordering for LiSa

/*
FREE MODE RECORDING IMPROVEMENT:

// Start free recording
fun void startFreeRecording()
{
    1 => isRecording;
    
    // Set a large buffer size
    60::second => dur maxDuration;
    mainLoop.duration(maxDuration);
    mainLoop.recPos(0::ms);
    mainLoop.recRamp(0::ms);
    mainLoop.loopStart(0::ms);
    
    // Start recording IMMEDIATELY for sample-accurate timing
    mainLoop.record(1);
    
    // Store the exact moment recording started (AFTER starting)
    now => recordStart;
}

// Stop free recording
fun void stopFreeRecording()
{
    // Calculate exact recorded length BEFORE stopping
    now - recordStart => loopLength;
    
    // Stop recording at the exact moment
    mainLoop.record(0);
    
    // Set the loop end point to exact recorded length
    mainLoop.loopEnd(loopLength);
    
    0 => isRecording;
    1 => loopExists;
    
    // Start playback immediately for smooth transition
    startPlayback();
}
*/

/*
ENHANCED PLAYBACK SYNCHRONIZATION:

fun void startPlayback()
{
    if (!loopExists) return;
    1 => isPlaying;

    // STEP 1: Configure all loops first (don't start yet)
    mainLoop.loopStart(0::ms);
    mainLoop.loopEnd(loopLength);
    mainLoop.loopEndRec(loopLength - 5::ms);
    mainLoop.loop(1);
    mainLoop.playPos(0::ms);
    
    // Configure all existing overdubs identically
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].loopStart(0::ms);
        overdubPlayers[i].loopEnd(loopLength);
        overdubPlayers[i].loopEndRec(loopLength - 5::ms);
        overdubPlayers[i].loop(1);
        overdubPlayers[i].playPos(0::ms);
    }
    
    // STEP 2: Start all playback simultaneously
    mainLoop.play(mainLoopActive);
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].play(overdubActive[i]);
    }
    
    // Wait one sample to ensure all started, then broadcast
    1::samp => now;
    loopStart.broadcast();
}
*/

/*
OVERDUB RECORDING - IMPROVED ORDERING:

fun void recordOverdub()
{
    loopStart => now;
    
    // Configure LiSa buffer with exact loop length
    overdubPlayers[overdubCount].duration(loopLength);
    overdubPlayers[overdubCount].recPos(0::ms);
    overdubPlayers[overdubCount].recRamp(0::ms);
    overdubPlayers[overdubCount].loopStart(0::ms);
    overdubPlayers[overdubCount].loopEnd(loopLength);
    
    // Start recording at exact loop boundary
    overdubPlayers[overdubCount].record(1);
    
    // Record for exactly one loop length (sample-accurate)
    loopLength => now;
    
    // Stop recording at exact loop boundary
    overdubPlayers[overdubCount].record(0);
    
    // Configure looping parameters
    overdubPlayers[overdubCount].loopEndRec(loopLength - 5::ms);
    overdubPlayers[overdubCount].loop(1);
    
    // CRITICAL: Wait for the next loop start to ensure perfect sync
    loopStart => now;
    
    // Now start playback at position 0, perfectly in sync
    overdubPlayers[overdubCount].playPos(0::ms);
    overdubPlayers[overdubCount].play(1);
    
    overdubCount++;
}
*/

// IMPROVEMENT: Much better timing accuracy
// REMAINING ISSUE: Waiting for second loopStart caused audible delay
// USER FEEDBACK: "still out of phase, when the main loop closes there is a delay"
