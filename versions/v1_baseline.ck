// LOOPSTATION VERSION 1: BASELINE
// State: Before erase function was added
// Features: Basic recording, overdubs, toggle loops, measure/free modes

// This version had:
// - Basic loop recording (measure and free modes)
// - Overdub functionality
// - Loop toggle with number keys (0-9)
// - Redo last overdub
// - BlueTurn pedal support

// MISSING:
// - Erase all function
// - Proper synchronization between main loop and overdubs
// - Professional loop pedal timing behavior

// Key synchronization issue:
// Overdubs were syncing to mainLoop.playPos() which caused phase misalignment

/*
CRITICAL CODE FROM v1 (PROBLEMATIC):

fun void recordOverdub()
{
    loopStart => now;
    
    overdubPlayers[overdubCount].duration(loopLength);
    overdubPlayers[overdubCount].record(1);
    
    loopLength => now;
    
    overdubPlayers[overdubCount].record(0);
    
    // PROBLEM: Syncing to current position instead of loop start
    overdubPlayers[overdubCount].playPos(mainLoop.playPos());
    overdubPlayers[overdubCount].loop(1);
    overdubPlayers[overdubCount].play(1);
    
    overdubCount++;
}
*/

// This version worked but had noticeable timing drift over multiple overdubs
