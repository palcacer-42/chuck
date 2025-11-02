// Octavator con cuarta voz (quinta justa arriba)

// =====================
// CONFIGURACION GANANCIAS
// =====================
0.8 => float preOrig;   0.3 => float postOrig;
0.4 => float preDown;   0.9 => float postDown;
0.4 => float preUp;     0.9 => float postUp;
0.4 => float preFifth; 0.9 => float postFifth;   // nueva voz de quinta

// =====================
// VOZ ORIGINAL
// =====================
adc => Gain preO => PitShift orig => Gain postO => dac;
preOrig => preO.gain;
1.0 => orig.shift;
postOrig => postO.gain;

// =====================
// VOZ OCTAVA BAJA
// =====================
adc => Gain preD => PitShift down => Gain postD => dac;
preDown => preD.gain;
0.5 => down.shift;
1.0 => down.mix;
postDown => postD.gain;

// =====================
// VOZ OCTAVA ALTA
// =====================
adc => Gain preU => PitShift up => Gain postU => dac;
preUp => preU.gain;
2.0 => up.shift;
1.0 => up.mix;
postUp => postU.gain;

// =====================
// VOZ QUINTA JUSTA
// =====================
adc => Gain preF => PitShift fifth => Gain postF => blackhole;
preFifth => preF.gain;
1.5 => fifth.shift;        // una quinta justa arriba (~7 semitonos)
1.0 => fifth.mix;
postFifth => postF.gain;

// =====================
// MANTENER EJECUCION
// =====================
while (true) 1::second => now;
