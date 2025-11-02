// === chugins demo for macOS M1 ===
// make sure GVerb, Bitcrusher, and ABSaturator are installed

// master gain
0.5 => dac.gain;

// create a sine oscillator
SinOsc s => Gain dry => dac;
s.freq(440);

// also create the effect chain
SinOsc s2 => GVerb rev => dac;
s2.freq(440);

SinOsc s3 => Bitcrusher crush => dac;
s3.freq(440);

SinOsc s4 => ABSaturator sat => dac;
s4.freq(440);

// set effect params
crush.bits(8);
crush.downsample(8);
sat.drive(5.0);

// function to toggle
fun void playWithEffect(int mode)
{
    if (mode == 0) {
        0.5 => dry.gain;
        0 => rev.gain;
        0 => crush.gain;
        0 => sat.gain;
        <<< "Dry signal" >>>;
    } else if (mode == 1) {
        0 => dry.gain;
        0.5 => rev.gain;
        0 => crush.gain;
        0 => sat.gain;
        <<< "Reverb (GVerb)" >>>;
    } else if (mode == 2) {
        0 => dry.gain;
        0 => rev.gain;
        0.5 => crush.gain;
        0 => sat.gain;
        <<< "Bitcrusher" >>>;
    } else {
        0 => dry.gain;
        0 => rev.gain;
        0 => crush.gain;
        0.5 => sat.gain;
        <<< "ABSaturator" >>>;
    }
}

// cycle effects
for (int i; true; i++)
{
    playWithEffect(i % 4);
    4::second => now;
}
