// =====================================================
// AUTOTUNE SIMPLE - CORREGIDO
// =====================================================

<<< "=== AUTOTUNE SIMPLE ===" >>>;

// ==================== CONFIGURACIÓN ====================

// Velocidad de corrección (0.01 = T-Pain, 0.5 = natural)
0.01 => float SPEED;

<<< "Velocidad de corrección:", SPEED >>>;
<<< "(0.01 = extremo, 0.5 = suave)" >>>;
<<< "" >>>;

// ==================== AUDIO ====================

// Entrada -> Autotune -> Salida
PitShift autotuner;
// route: adc -> input gain -> autotuner -> wet gain (effects chain connected later)
adc => Gain input => autotuner => Gain wet;

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

complex spectrum[FFT_SIZE/2];

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

// Conversiones
fun float freq2midi(float f) {
    // Math.log2 may not be available on all ChucK builds; use log / log(2)
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
        
        fft.upchuck() @=> UAnaBlob blob;  // Método más moderno
        
        // Calcular energía
        0.0 => float e;
        for (0 => int i; i < FFT_SIZE/2; i++) {
            blob.fval(i) => float m;  // Magnitud directamente
            m * m +=> e;
        }
        e / (FFT_SIZE/2) => e;
        energy * 0.9 + e * 0.1 => energy;
        
    // DEBUG: print raw energy and a few FFT bins every 50 frames
    dbgCount++;
        if (dbgCount % 50 == 0) {
            <<< "dbg raw e=", e, "energy=", energy,
                "bins:", blob.fval(1), blob.fval(2), blob.fval(3), blob.fval(4), blob.fval(5) >>>;
        }

        // Si hay señal suficiente (threshold reducido para pruebas)
        if (energy > 0.0005) {
            // Buscar pico
            0.0 => float maxMag;
            0 => int maxBin;
            
            // Buscar en todo el rango (empezando en 1 para coger fundamentales bajas)
            for (1 => int bin; bin < FFT_SIZE/2; bin++) {
                blob.fval(bin) => float m;
                if (m > maxMag) {
                    m => maxMag;
                    bin => maxBin;
                }
            }

            // debug: print energy & peak occasionally
            if (maxMag > 0.0001) {
                <<< "dbg: e=", e, "energy=", energy, "maxMag=", maxMag, "bin=", maxBin >>>;
            }
            
                if (maxBin > 0) {
                    // Convertir bin a frecuencia
                    // bin * (sampleRate) / FFT_SIZE
                    maxBin * (second / samp) / FFT_SIZE => float freq;

                    if (freq > 80 && freq < 800) {
                        // Suavizar
                        detectedFreq * 0.7 + freq * 0.3 => detectedFreq;
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
        
    if (energy > 0.0005 && detectedFreq > 80) {
            // Convertir a MIDI
            freq2midi(detectedFreq) => float midi;
            
            // Redondear a nota en escala
            int midiInt;
            Math.round(midi) $ int => midiInt;
            snapToScale(midiInt) => int correctedMidi;
            
            // Volver a frecuencia
            midi2freq(correctedMidi) => targetFreq;
            
            // Calcular shift
            // Many pitch-shifters expect semitones rather than ratios.
            // Compute ratio and semitone values, then apply semitone shift.
            targetFreq / detectedFreq => float desiredRatio;
            // semitones = 12 * log2(ratio) -> use log / log(2)
            (12.0 * (Math.log(desiredRatio) / Math.log(2.0))) => float desiredSemis;

            // Suavizar semitonos
            currentShift + ((desiredSemis - currentShift) * SPEED) => currentShift;

            // Limitar a +/- 24 semitonos para evitar artefactos
            if (currentShift < -24.0) -24.0 => currentShift;
            if (currentShift > 24.0) 24.0 => currentShift;

            // Debug print
            <<< "detected:", Math.round(detectedFreq), "Hz",
                "target:", Math.round(targetFreq), "Hz",
                "ratio:", desiredRatio,
                "semis:", desiredSemis,
                "applied(semi):", currentShift >>>;

            // Aplicar semitonos al PitShift (many implementations accept semitones)
            currentShift => autotuner.shift;
        }
    }
}

spork ~ correct();

<<< "✓ Corrector activo" >>>;

// ==================== EFECTOS ====================

wet => Chorus chorus => NRev reverb => Gain master => dac;

0.3 => chorus.mix;
0.15 => reverb.mix;
0.8 => master.gain;

<<< "✓ Efectos agregados" >>>;

// ==================== MONITOR ====================

fun void monitor() {
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] @=> string notes[];
    
    while (true) {
        1::second => now;
        
    if (energy > 0.0005) {
            freq2midi(detectedFreq) => float m1;
            freq2midi(targetFreq) => float m2;
            
            int midi1;
            int midi2;
            Math.round(m1) $ int => midi1;
            Math.round(m2) $ int => midi2;
            
            <<< "" >>>;
            <<< "🎵 AUTOTUNE" >>>;
            <<< "In :", Math.round(detectedFreq), "Hz", 
                notes[midi1 % 12], (midi1 / 12 - 1) >>>;
            <<< "Out:", Math.round(targetFreq), "Hz", 
                notes[midi2 % 12], (midi2 / 12 - 1) >>>;
            <<< "Shift:", currentShift >>>;
        } else {
            <<< "⏸ Esperando voz..." >>>;
        }
    }
}

spork ~ monitor();

// ==================== CALIBRACIÓN ====================

<<< "" >>>;
<<< "Calibrando... Silencio por 2 segundos" >>>;
2::second => now;

<<< "" >>>;
<<< "╔════════════════════════════════════╗" >>>;
<<< "║  AUTOTUNE LISTO                   ║" >>>;
<<< "╚════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "🎤 ¡CANTA!" >>>;
<<< "" >>>;
<<< "Configuración:" >>>;
<<< "  Escala: Do Mayor" >>>;
<<< "  Velocidad:", SPEED >>>;
<<< "  Mix: 90% procesado" >>>;
<<< "" >>>;
<<< "Para cambiar velocidad, edita línea 10:" >>>;
<<< "  0.01 => float SPEED;  // T-Pain extremo" >>>;
<<< "  0.05 => float SPEED;  // Normal" >>>;
<<< "  0.5 => float SPEED;   // Muy suave" >>>;
<<< "" >>>;

while (true) {
    1::second => now;
}
