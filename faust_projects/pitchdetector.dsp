import("stdfaust.lib");

declare name "Pitch Detector";
declare author "You";
declare license "MIT";

// Mic monitor to avoid feedback (0% by default)
mon = hslider("Monitor [unit:%]", 0, 0, 100, 1) / 100.0;

// One-attach-per-meter helpers (1 in -> 1 out)
attachFreq = _ <: _, (_ : an.pitchTracker(4, 0.02)
                           : si.smooth(ba.tau2pole(0.05))
                           : vbargraph("[0] Frequency [unit:Hz]", 20, 5000))
                  : attach;

attachMidi = _ <: _, (_ : an.pitchTracker(4, 0.02)
                           : si.smooth(ba.tau2pole(0.05))
                           : ba.hz2midikey : round
                           : vbargraph("[1] MIDI Note", 0, 127))
                  : attach;

attachNoteClass = _ <: _, (_ : an.pitchTracker(4, 0.02)
                              : si.smooth(ba.tau2pole(0.05))
                              : ba.hz2midikey : round
                              : (_ <: _, (_ : /(12) : int : *(12)) : -)
                              : vbargraph("[2] Note Class [tooltip:0=C,1=C#,2=D,3=D#,4=E,5=F,6=F#,7=G,8=G#,9=A,10=A#,11=B]", 0, 11))
                     : attach;

attachOctave = _ <: _, (_ : an.pitchTracker(4, 0.02)
                            : si.smooth(ba.tau2pole(0.05))
                            : ba.hz2midikey : round
                            : /(12) : int : -(1)
                            : vbargraph("[3] Octave", -1, 9))
                   : attach;

process = _ * mon : attachFreq : attachMidi : attachNoteClass : attachOctave;
