// =====================================================
// AUTOTUNE OPTIMAL - MERGED VERSION
// =====================================================

<<< "=== AUTOTUNE OPTIMAL ===" >>>;

// ==================== CONFIGURACIÓN ====================

// Velocidad de corrección (0.01 = T-Pain, 0.5 = natural)
0.01 => float SPEED;

// Umbral optimizado basado en mediciones previas
0.00005 => float ENERGY_THRESHOLD;  // Se calibrará dinámicamente

<<< "Velocidad de corrección:", SPEED >>>;
<<< "(0.01 = extremo, 0.5 = suave)" >>>;
<<< "" >>>;

// ==================== AUDIO ====================

// Entrada -> Autotune -> Salida
PitShift autotuner;
adc => Gain input => autotuner => Gain wet;

// Aumentar ganancia de entrada para mejorar detección
5.0 => input.gain;

input => Gain dry => dac;
0.1 => dry.gain;  // Poco dry para oír el efecto

// PitShift solo tiene .shift, no .mix
1 => autotuner.shift;

<<< "✓ Cadena de audio configurada" >>>;

// ==================== ANÁLISIS ====================

input => FFT fft => blackhole;

512 => int FFT_SIZE;
FFT_SIZE => fft.size;
Windowing.hann(FFT_SIZE) => fft.window;

<<< "✓ FFT configurado" >>>;

// ==================== ESCALA MUSICAL ====================

// Do Mayor: C D E F G A B
[0, 2, 4, 5, 7, 9, 11] @=> int scale[];

// Función simple: redondear a nota más cercana
fun int snapToScale(int note) {
    note % 12 => int n;
    note / 12 => int octave;
    
    // Buscar nota más cercana
    100 => int minDist;
    0 => int closest;
    
    for (0 => int i; i < scale.cap(); i++) {
        Math.abs(n - scale[i]) => int dist;
        if (dist < minDist) {
            dist => minDist;
            scale[i] => closest;
        }
    }
    
    return octave * 12 + closest;
}

// Conversiones (compatible con versiones antiguas de ChucK)
fun float freq2midi(float f) {
    return 69.0 + 12.0 * (Math.log(f / 440.0) / Math.log(2.0));
}

fun float midi2freq(float m) {
    return 440.0 * Math.pow(2.0, (m - 69.0) / 12.0);
}

<<< "✓ Funciones de escala listas" >>>;

// ==================== VARIABLES ====================

0.0 => float detectedFreq;
0.0 => float targetFreq;
0.0 => float currentShift;
0.0 => float energy;
0 => int dbgCount;

// ==================== DETECTOR DE PITCH ====================

fun void pitchDetect() {
    while (true) {
        FFT_SIZE::samp => now;
        
        fft.upchuck() @=> UAnaBlob blob;
        
        // Calcular energía con normalización mejorada
        0.0 => float e;
        for (0 => int i; i < FFT_SIZE/2; i++) {
            blob.fval(i) => float m;
            m * m +=> e;
        }
        e / (FFT_SIZE/2) => e;
        energy * 0.9 + e * 0.1 => energy;
        
        // Debug periódico de energía
        dbgCount++;
        if (dbgCount % 100 == 0) {
            <<< "Energy:", energy, "Threshold:", ENERGY_THRESHOLD >>>;
        }
        
        // Si hay señal suficiente
        if (energy > ENERGY_THRESHOLD) {
            // Buscar pico en rango vocal extendido
            0.0 => float maxMag;
            0 => int maxBin;
            
            // Búsqueda optimizada en el rango vocal
            for (1 => int bin; bin < FFT_SIZE/4; bin++) {
                blob.fval(bin) => float m;
                if (m > maxMag) {
                    m => maxMag;
                    bin => maxBin;
                }
            }
            
            if (maxBin > 0) {
                // Convertir bin a frecuencia (corregido)
                maxBin * (second / samp) / FFT_SIZE => float freq;
                
                if (freq > 80 && freq < 800) {
                    // Suavizado adaptativo
                    detectedFreq * 0.7 + freq * 0.3 => detectedFreq;
                    
                    // Debug ocasional
                    if (dbgCount % 100 == 0) {
                        <<< "Detected:", Math.round(detectedFreq), "Hz" >>>;
                    }
                }
            }
        }
    }
}

spork ~ pitchDetect();

<<< "✓ Detector de pitch activo" >>>;

// ==================== CORRECCIÓN ====================

fun void correct() {
    while (true) {
        10::ms => now;
        
        if (energy > ENERGY_THRESHOLD && detectedFreq > 80) {
            // Convertir a MIDI
            freq2midi(detectedFreq) => float midi;
            
            // Redondear a nota en escala
            Math.round(midi) $ int => int midiInt;
            snapToScale(midiInt) => int correctedMidi;
            
            // Volver a frecuencia
            midi2freq(correctedMidi) => targetFreq;
            
            // Calcular shift en SEMITONOS (más correcto para PitShift)
            targetFreq / detectedFreq => float desiredRatio;
            (12.0 * (Math.log(desiredRatio) / Math.log(2.0))) => float desiredSemis;
            
            // Suavizar
            currentShift + ((desiredSemis - currentShift) * SPEED) => currentShift;
            
            // Limitar a rango razonable
            if (currentShift < -24.0) -24.0 => currentShift;
            if (currentShift > 24.0) 24.0 => currentShift;
            
            // Aplicar
            currentShift => autotuner.shift;
        }
    }
}

spork ~ correct();

<<< "✓ Corrector activo" >>>;

// ==================== EFECTOS ====================

// Cadena de efectos limpia (sin duplicación)
wet => Chorus chorus => NRev reverb => Gain master => dac;

0.3 => chorus.mix;
0.15 => reverb.mix;
0.8 => master.gain;

<<< "✓ Efectos agregados" >>>;

// ==================== MONITOR ====================

fun void monitor() {
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] @=> string notes[];
    
    while (true) {
        500::ms => now;
        
        if (energy > ENERGY_THRESHOLD) {
            freq2midi(detectedFreq) => float m1;
            freq2midi(targetFreq) => float m2;
            Math.round(m1) $ int => int midi1;
            Math.round(m2) $ int => int midi2;

            // Ensure midi notes are in valid range
            midi1 % 12 => int noteIndex1;
            midi2 % 12 => int noteIndex2;
            if (noteIndex1 < 0) noteIndex1 + 12 => noteIndex1;
            if (noteIndex2 < 0) noteIndex2 + 12 => noteIndex2;
            
            <<< "======================" >>>;
            <<< "🎵 IN :", notes[noteIndex1] + Std.itoa(midi1/12 - 1), 
                "(", Math.round(detectedFreq), "Hz)" >>>;
            <<< "🎯 OUT:", notes[noteIndex2] + Std.itoa(midi2/12 - 1), 
                "(", Math.round(targetFreq), "Hz)" >>>;
            <<< "📊 Shift:", Math.round(currentShift * 10.0) / 10.0, "semitones" >>>;
            <<< "----------------------" >>>;
        } else {
            <<< "⏸ Esperando voz... (energy:", 
                Math.round(energy * 1000000.0) / 1000000.0, ")" >>>;
        }
    }
}

spork ~ monitor();

// ==================== CALIBRACIÓN ====================

<<< "" >>>;
<<< "Calibrando... Silencio por 2 segundos" >>>;
0.0 => float maxEnergy;
20 => int samples;

// Medir ruido ambiente con más precisión
for (0 => int i; i < samples; i++) {
    100::ms => now;
    if (energy > maxEnergy) energy => maxEnergy;
}

// Ajustar umbral dinámicamente basado en mediciones
maxEnergy * 5.0 => ENERGY_THRESHOLD;
<<< "Umbral de energía calibrado:", ENERGY_THRESHOLD >>>;
<<< "(Nivel máximo de ruido:", maxEnergy, ")" >>>;

<<< "" >>>;
<<< "╔════════════════════════════════════╗" >>>;
<<< "║  AUTOTUNE OPTIMAL - LISTO         ║" >>>;
<<< "╚════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "🎤 ¡CANTA!" >>>;
<<< "" >>>;
<<< "Configuración actual:" >>>;
<<< "  Escala: Do Mayor (C Major)" >>>;
<<< "  Velocidad:", SPEED, "(", SPEED < 0.05 ? "T-Pain" : SPEED < 0.2 ? "Normal" : "Suave", ")" >>>;
<<< "  Entrada: Gain", input.gain() >>>;
<<< "  Mix: Wet", wet.gain(), "/ Dry", dry.gain() >>>;
<<< "  Efectos: Chorus", chorus.mix(), "Reverb", reverb.mix() >>>;
<<< "  Método: Semitone-based shifting" >>>;
<<< "" >>>;
<<< "Mejoras en esta versión:" >>>;
<<< "  ✓ Calibración dinámica de umbral" >>>;
<<< "  ✓ Shifting por semitonos (más preciso)" >>>;
<<< "  ✓ Ganancia de entrada optimizada" >>>;
<<< "  ✓ Conversión de frecuencia corregida" >>>;
<<< "  ✓ Cadena de audio sin duplicación" >>>;
<<< "" >>>;
<<< "Para ajustar:" >>>;
<<< "  Velocidad (edita línea 10):" >>>;
<<< "    0.01 => float SPEED;  // T-Pain extremo" >>>;
<<< "    0.05 => float SPEED;  // Normal" >>>;
<<< "    0.5 => float SPEED;   // Suave/Natural" >>>;
<<< "" >>>;

while (true) {
    1::second => now;
}
