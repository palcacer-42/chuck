// LOOPSTATION VERSION 2: ERASE FUNCTION ADDED
// State: Added eraseAll() function, first sync fix attempt

// NEW FEATURES:
// - Erase all loops with 'e' key in both modes
// - Clear LED display on erase
// - Reset all state variables

// SYNCHRONIZATION FIX ATTEMPT #1:
// Changed overdub playback to start from position 0 instead of syncing to mainLoop.playPos()

/*
ERASE FUNCTION CODE:

fun void eraseAll()
{
    <<< "\nErasing all loops..." >>>;
    
    // Stop playback
    0 => isPlaying;
    
    // Stop and clear main loop
    mainLoop.play(0);
    mainLoop.record(0);
    mainLoop.loop(0);
    
    // Stop and clear all overdubs
    for (0 => int i; i < overdubCount; i++)
    {
        overdubPlayers[i].play(0);
        overdubPlayers[i].record(0);
        overdubPlayers[i].loop(0);
    }
    
    // Reset state
    0 => loopExists;
    0 => isRecording;
    0 => isOverdubbing;
    0 => overdubCount;
    1 => mainLoopActive;
    
    // Reset all overdub active flags
    for (0 => int i; i < 10; i++)
    {
        1 => overdubActive[i];
    }
    
    // Clear the LED display
    chout <= "\r";
    for (0 => int i; i < ledCount; i++)
    {
        chout <= "○";
        if ((i + 1) % 4 == 0 && i < ledCount - 1) chout <= " ";
    }
    chout <= " ";
    chout.flush();
    
    <<< "✓ All loops cleared! Ready to record." >>>;
}
*/

/*
SYNC FIX #1 CODE:

fun void recordOverdub()
{
    loopStart => now;
    
    overdubPlayers[overdubCount].record(1);
    loopLength => now;
    overdubPlayers[overdubCount].record(0);
    
    // FIX: Start from position 0 instead of current position
    overdubPlayers[overdubCount].playPos(0::ms);  
    overdubPlayers[overdubCount].loopEndRec(loopLength - 5::ms);
    overdubPlayers[overdubCount].loop(1);
    overdubPlayers[overdubCount].play(1);
    
    overdubCount++;
}
*/

// IMPROVEMENT: Better sync than v1, but still not perfect
// REMAINING ISSUE: Multiple commands between record stop and play start
