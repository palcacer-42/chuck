// Amplificador de Guitarra con Efectos Clásicos
// Ejecutar con: chuck --adc:1 --dac:1 amp_guitarra.ck

// ============= CONSTANTES DE DELAY PARA REVERB =============
29.7::ms => dur COMB1_DELAY;
37.1::ms => dur COMB2_DELAY;
41.1::ms => dur COMB3_DELAY;

// ============= ENTRADA DE AUDIO =============
adc => Gain input => blackhole;

// ============= CADENA DE EFECTOS =============
// Pre-gain (para ajustar nivel de entrada)
input => Gain preGain => Gain cleanSignal => dac;

// Canal con distorsión
input => Gain distGain => Gain distortionMix => dac;

// Canal con delay
input => Gain delayGain => Delay delay1 => Gain delayFeedback => Gain delayMix => dac;
delayFeedback => delay1;

// Canal con reverb (usando comb filters)
// Separate send/return to avoid creating a feedback loop (comb outputs must not feed the send node).
input => Gain reverbGain => Gain reverbSend => dac;   // reverbSend is the source sent into combs
// combs feed into a reverb return bus (reverbOut), then mixed by reverbWet to the DAC
reverbSend => Delay comb1 => Gain comb1Gain => Gain reverbOut;
reverbSend => Delay comb2 => Gain comb2Gain => reverbOut;
reverbSend => Delay comb3 => Gain comb3Gain => reverbOut;
reverbOut => Gain reverbWet => dac;

// ============= PARÁMETROS INICIALES =============
// Ganancia de entrada
2 => preGain.gain;

// Canal limpio
1 => cleanSignal.gain;

// Distorsión (OFF por defecto)
0.80 => distGain.gain;
0.0 => distortionMix.gain;

// Delay (configuración básica)
1 => delayGain.gain;
300::ms => delay1.max => delay1.delay;
0.4 => delayFeedback.gain;
0.0 => delayMix.gain;

// Reverb (configuración de comb filters)
// Increase send/wet and comb gains for a more present reverb by default.
// Expose a quick variable so you can tweak wet level easily.
0.75 => reverbGain.gain;       // stronger send into the reverb network
COMB1_DELAY => comb1.max => comb1.delay;
COMB2_DELAY => comb2.max => comb2.delay;
COMB3_DELAY => comb3.max => comb3.delay;
0.9 => comb1Gain.gain;       // stronger feedback per comb (be careful >0.95)
0.9 => comb2Gain.gain;
0.9 => comb3Gain.gain;
// Reverb wet mix (adjustable). Increase for a more present reverb.
0.55 => reverbWet.gain;      // noticeably more wet

// Optional extra algorithmic reverb stage for richness (disabled by default)
// Uncomment the NRev chain below if you want an even bigger reverb.
// reverbWet => NRev extraRev => Gain extraRevGain => dac;
// 0.35 => extraRevGain.gain;

// ============= INSTRUCCIONES =============
<<< "========================================" >>>;
<<< "  AMPLIFICADOR DE GUITARRA - ChucK" >>>;
<<< "========================================" >>>;
<<< "" >>>;
<<< "CONTROLES DISPONIBLES:" >>>;
<<< "Edita los valores a continuación para cambiar los efectos" >>>;
<<< "" >>>;
<<< "EFECTOS:" >>>;
<<< "1. Canal Limpio: cleanSignal.gain (0.0 - 1.0)" >>>;
<<< "2. Distorsión: distGain.gain y distortionMix.gain" >>>;
<<< "3. Delay: delayGain.gain, delay1.delay, delayFeedback.gain" >>>;
<<< "4. Reverb: reverbGain.gain, reverbWet.gain" >>>;
<<< "" >>>;
<<< "VALORES ACTUALES:" >>>;
<<< "- Limpio:", cleanSignal.gain() >>>;
<<< "- Distorsión:", distGain.gain() >>>;
<<< "- Delay:", delayGain.gain() >>>;
<<< "- Reverb:", reverbGain.gain() >>>;
<<< "" >>>;
<<< "Amplificador funcionando... (Ctrl+C para detener)" >>>;
<<< "========================================" >>>;

// ============= PRESETS PARA PROBAR =============
// Descomenta el preset que quieras probar:

// PRESET 1: Solo limpio
// Ya está configurado arriba

// PRESET 2: Con delay (descomenta las siguientes líneas)
// 0.6 => delayGain.gain;
// 0.5 => delayMix.gain;

// PRESET 3: Con distorsión (descomenta las siguientes líneas)
// 2.5 => distGain.gain;
// 0.6 => distortionMix.gain;

// PRESET 4: Con reverb (descomenta las siguientes líneas)
// 0.7 => reverbGain.gain;
// 0.4 => reverbWet.gain;

// PRESET 5: Todo activado - Rock clásico (descomenta las siguientes líneas)
// 0.5 => cleanSignal.gain;
// 1.8 => distGain.gain;
// 0.5 => distortionMix.gain;
// 0.3 => delayGain.gain;
// 0.3 => delayMix.gain;
// 0.4 => reverbGain.gain;
// 0.2 => reverbWet.gain;

// Loop infinito para mantener el programa corriendo
while(true)
{
    1::second => now;
}