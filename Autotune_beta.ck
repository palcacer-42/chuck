// =====================================================
// AUTOTUNE - CORRECCION AUTOMATICA DE AFINACION
// =====================================================
// Estilo T-Pain / Cher / Pop moderno

<<< "=== AUTOTUNE AUTOMATICO ===" >>>;
<<< "" >>>;

// ==================== CONFIGURACION DE ESCALA ====================

// Escala musical (Do Mayor por defecto)
// 0=C, 1=C#, 2=D, 3=D#, 4=E, 5=F, 6=F#, 7=G, 8=G#, 9=A, 10=A#, 11=B
[0, 2, 4, 5, 7, 9, 11] @=> int SCALE[];  // Do Mayor: C D E F G A B


// Nota base (MIDI)
60 => int BASE_NOTE;  // C4 (Do central)

// Velocidad de correccion (mas bajo = mas rapido = efecto T-Pain)
0.2 => float CORRECTION_SPEED;  // 0.01 = instantaneo, 0.5 = suave

<<< "Escala: Do Mayor (C D E F G A B)" >>>;
<<< "Nota base:", BASE_NOTE, "(C4)" >>>;
<<< "Velocidad:", CORRECTION_SPEED >>>;
<<< "" >>>;

// ==================== ENTRADA DE VOZ ====================

adc => Gain voiceIn => PitShift pitcher => Gain wet => dac;

// Tambien mantener algo de senal original para claridad
voiceIn => Gain dry => dac;

0.6 => voiceIn.gain;
0.9 => wet.gain;    // Senal procesada
0.1 => dry.gain;    // Senal original (10% para naturalidad)

1.0 => pitcher.mix;  // 100% procesado
1.0 => pitcher.shift; // Ratio inicial (sera ajustado)

<<< "? Cadena de audio configurada" >>>;

// ==================== ANALISIS FFT PARA PITCH DETECTION ====================

voiceIn => FFT fft => blackhole;

1024 => int FFT_SIZE;
FFT_SIZE => fft.size;
Windowing.hann(FFT_SIZE) => fft.window;

complex spectrum[FFT_SIZE/2];

<<< "? Analisis FFT configurado" >>>;

// ==================== VARIABLES DE ESTADO ====================

0.0 => float detectedPitch;      // Frecuencia detectada (Hz)
0.0 => float targetPitch;        // Frecuencia objetivo (Hz)
0.0 => float currentShift;       // Shift actual aplicado
0.0 => float voiceEnergy;        // Energia de la senal
0.05 => float ENERGY_THRESHOLD;  // Umbral de activacion

<<< "? Variables inicializadas" >>>;

// ==================== FUNCIONES DE CONVERSION ====================

// Frecuencia a nota MIDI
fun float freqToMidi(float freq) {
    if (freq <= 0) return 0.0;
    return 69.0 + 12.0 * Math.log2(freq / 440.0);
}

// Nota MIDI a frecuencia
fun float midiToFreq(float midi) {
    return 440.0 * Math.pow(2.0, (midi - 69.0) / 12.0);
}

// Cuantizar a la nota mas cercana en la escala
fun float quantizeToScale(float midiNote) {
    Math.round(midiNote) $ int => int midiInt;
    
    // Extraer octava y nota dentro de la octava
    midiInt % 12 => int noteInOctave;
    midiInt / 12 => int octave;
    
    // Encontrar nota mas cercana en la escala
    1000 => int minDist;
    0 => int closestNote;
    octave => int targetOctave;  // Inicializar variable
    
    for (0 => int i; i < SCALE.cap(); i++) {
        Math.abs(noteInOctave - SCALE[i]) => int dist;
        
        // Tambien considerar la octava anterior/siguiente
        Math.abs(noteInOctave - SCALE[i] + 12) => int distUp;
        Math.abs(noteInOctave - SCALE[i] - 12) => int distDown;
        
        if (dist < minDist) {
            dist => minDist;
            SCALE[i] => closestNote;
            octave => targetOctave;
        }
        if (distUp < minDist) {
            distUp => minDist;
            SCALE[i] => closestNote;
            octave + 1 => targetOctave;
        }
        if (distDown < minDist) {
            distDown => minDist;
            SCALE[i] => closestNote;
            octave - 1 => targetOctave;
        }
    }
    
    // Reconstruir nota MIDI cuantizada
    return (targetOctave * 12 + closestNote) $ float;
}

<<< "? Funciones de conversion listas" >>>;

// ==================== PITCH DETECTION ====================

fun void pitchDetector() {
    while (true) {
        FFT_SIZE::samp => now;
        
        // Obtener espectro
        fft.spectrum(spectrum);
        
        // Calcular energia total
        0.0 => float totalEnergy;
        for (0 => int i; i < FFT_SIZE/2; i++) {
            (spectrum[i]$polar).mag => float mag;
            mag * mag +=> totalEnergy;
        }
        totalEnergy / (FFT_SIZE/2) => totalEnergy;
        
        // Suavizar energia
        voiceEnergy * 0.8 + totalEnergy * 0.2 => voiceEnergy;
        
        // Solo procesar si hay senal suficiente
        if (voiceEnergy > ENERGY_THRESHOLD) {
            // Buscar pico fundamental en rango vocal (80 - 800 Hz)
            0.0 => float maxMag;
            0 => int maxBin;
            
            // Rango de bins correspondiente a 80-800 Hz
            10 => int minBin;
            150 => int maxBinSearch;
            
            for (minBin => int bin; bin < maxBinSearch; bin++) {
                (spectrum[bin]$polar).mag => float mag;
                if (mag > maxMag) {
                    mag => maxMag;
                    bin => maxBin;
                }
            }
            
            // Convertir bin a frecuencia
            if (maxMag > 0.01 && maxBin > 0) {
                maxBin * second / samp / (FFT_SIZE/2) => float freq;
                
                // Verificar que este en rango valido
                if (freq > 80 && freq < 800) {
                    // Suavizado de pitch detectado
                    detectedPitch * 0.7 + freq * 0.3 => detectedPitch;
                }
            }
        }
    }
}

spork ~ pitchDetector();

<<< "? Detector de pitch activo" >>>;

// ==================== CORRECCION DE PITCH (AUTOTUNE) ====================

fun void autotuneEngine() {
    while (true) {
        10::ms => now;
        
        if (voiceEnergy > ENERGY_THRESHOLD && detectedPitch > 80) {
            // Convertir pitch detectado a MIDI
            freqToMidi(detectedPitch) => float midiNote;
            
            // Cuantizar a la escala
            quantizeToScale(midiNote) => float targetMidi;
            
            // Convertir de vuelta a frecuencia
            midiToFreq(targetMidi) => targetPitch;
            
            // Calcular ratio de shift necesario
            targetPitch / detectedPitch => float desiredShift;
            
            // Suavizar la correccion (interpolacion)
            currentShift + ((desiredShift - currentShift) * CORRECTION_SPEED) => currentShift;
            
            // Limitar rango (0.5x a 2.0x)
            if (currentShift < 0.5) 0.5 => currentShift;
            if (currentShift > 2.0) 2.0 => currentShift;
            
            // Aplicar al pitch shifter
            currentShift => pitcher.shift;
        } else {
            // Sin senal, volver a neutral
            currentShift * 0.95 + 1.0 * 0.05 => currentShift;
            currentShift => pitcher.shift;
        }
    }
}

spork ~ autotuneEngine();

<<< "? Motor de autotune activo" >>>;

// ==================== EFECTOS ADICIONALES ====================

// Agregar efectos para sonido mas profesional
wet => Chorus chorus => NRev reverb => Gain master => dac;

0.2 => chorus.mix;
0.5 => chorus.modFreq;
0.1 => chorus.modDepth;

0.15 => reverb.mix;
0.8 => master.gain;

<<< "? Efectos agregados (Chorus + Reverb)" >>>;

// ==================== CONTROL OSC ====================

8000 => int OSC_PORT;
OscIn oin;
OscMsg msg;

fun void oscController() {
    if (!oin.port(OSC_PORT)) return;
    
    oin.addAddress("");
    
    while (true) {
        oin => now;
        while (oin.recv(msg)) {
            msg.address => string addr;
            
            // Obtener valor float
            msg.getFloat(0) => float value;
            
            if (addr == "/speed" || addr == "/correction") {
                // Control de velocidad de correccion
                0.01 + (value * 0.49) => CORRECTION_SPEED;
                <<< "Velocidad:", CORRECTION_SPEED >>>;
            }
            else if (addr == "/wetdry" || addr == "/mix") {
                // Mix wet/dry
                value => wet.gain;
                1.0 - value => dry.gain;
                <<< "Mix:", value >>>;
            }
            else if (addr == "/chorus") {
                value => chorus.mix;
            }
            else if (addr == "/reverb") {
                value * 0.5 => reverb.mix;
            }
            else if (addr == "/threshold") {
                value * 0.1 => ENERGY_THRESHOLD;
                <<< "Threshold:", ENERGY_THRESHOLD >>>;
            }
        }
    }
}

if (oin.port(OSC_PORT)) {
    <<< "? Control OSC activo (puerto", OSC_PORT, ")" >>>;
    spork ~ oscController();
}

// ==================== CAMBIO DE ESCALAS ====================

fun void scaleChanger() {
    // Cambiar entre diferentes escalas
    [
    [0, 2, 4, 5, 7, 9, 11],     // Do Mayor
    [0, 2, 3, 5, 7, 8, 10],     // Do Menor
    [0, 2, 4, 7, 9],            // Pentatonica Mayor
    [0, 3, 5, 7, 10],           // Pentatonica Menor
    [0, 2, 4, 6, 8, 10]         // Escala de Tonos Enteros
    ] @=> int scales[][];
    
    ["Do Mayor", "Do Menor", "Pentatonica Mayor", "Pentatonica Menor", "Tonos Enteros"] @=> string names[];
    
    0 => int currentScale;
    
    while (true) {
        12::second => now;
        
        currentScale++;
        if (currentScale >= scales.cap()) 0 => currentScale;
        
        scales[currentScale] @=> SCALE;
        
        <<< "" >>>;
        <<< "? Cambio de escala:", names[currentScale] >>>;
    }
}

// Descomentar para cambio automatico de escalas
// spork ~ scaleChanger();

// ==================== MONITOR VISUAL ====================

fun void visualMonitor() {
    while (true) {
        500::ms => now;
        
        if (voiceEnergy > ENERGY_THRESHOLD) {
            <<< "" >>>;
            <<< "???????????????????????????????????" >>>;
            <<< "? AUTOTUNE ACTIVO" >>>;
            <<< "???????????????????????????????????" >>>;
            
            // Mostrar pitch detectado
            freqToMidi(detectedPitch) => float midiDetected;
            <<< "Detectado:", Math.round(detectedPitch), "Hz ?", 
            getMidiNoteName(Math.round(midiDetected) $ int) >>>;
            
            // Mostrar pitch objetivo
            freqToMidi(targetPitch) => float midiTarget;
            <<< "Corregido:", Math.round(targetPitch), "Hz ?", 
            getMidiNoteName(Math.round(midiTarget) $ int) >>>;
            
            // Mostrar correccion aplicada
            (currentShift - 1.0) * 100 => float cents;
            <<< "Ajuste:", Math.round(cents), "cents" >>>;
            
            // Barra visual de correccion
            "" => string bar;
            Math.round(Math.fabs(cents) / 5) $ int => int barLen;
            for (0 => int i; i < barLen; i++) "?" +=> bar;
            
            if (cents > 0) {
                <<< "? ", bar >>>;
            } else if (cents < 0) {
                <<< "? ", bar >>>;
            } else {
                <<< "? Afinado!" >>>;
            }
        } else {
            <<< "?  Esperando voz... (energia:", 
            Math.round(voiceEnergy * 1000), ")" >>>;
        }
    }
}

// Funcion auxiliar para nombres de notas
fun string getMidiNoteName(int midi) {
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] @=> string notes[];
    midi % 12 => int note;
    midi / 12 - 1 => int octave;
    return notes[note] + octave;
}

spork ~ visualMonitor();

// ==================== CALIBRACION ====================

<<< "" >>>;
<<< "??????????????????????????????????????????" >>>;
<<< "?  CALIBRACION                          ?" >>>;
<<< "??????????????????????????????????????????" >>>;
<<< "" >>>;
<<< "? Permanece en SILENCIO por 2 segundos..." >>>;

2::second => now;

<<< "" >>>;
<<< "? Calibracion completada" >>>;
<<< "  Nivel de ruido:", Math.round(voiceEnergy * 1000) >>>;

// Ajustar threshold
voiceEnergy * 2.0 => ENERGY_THRESHOLD;

<<< "  Threshold ajustado:", Math.round(ENERGY_THRESHOLD * 1000) >>>;
<<< "" >>>;

// ==================== INSTRUCCIONES ====================

<<< "??????????????????????????????????????????" >>>;
<<< "?  AUTOTUNE LISTO                       ?" >>>;
<<< "??????????????????????????????????????????" >>>;
<<< "" >>>;
<<< "? !CANTA! Tu voz sera autotuneada" >>>;
<<< "" >>>;
<<< "CONFIGURACION ACTUAL:" >>>;
<<< "  Escala: Do Mayor (C D E F G A B)" >>>;
<<< "  Velocidad:", CORRECTION_SPEED, "(0.01=T-Pain, 0.5=Natural)" >>>;
<<< "  Mix: 90% procesado, 10% original" >>>;
<<< "" >>>;
<<< "TIPS:" >>>;
<<< "  1. Canta notas sostenidas: AAAA" >>>;
<<< "  2. Canta escalas: Do Re Mi Fa Sol" >>>;
<<< "  3. Prueba melodias simples" >>>;
<<< "" >>>;
<<< "CONTROLES OSC (iPad):" >>>;
<<< "  /speed (0-1)    - Velocidad de correccion" >>>;
<<< "  /wetdry (0-1)   - Mezcla efecto/original" >>>;
<<< "  /chorus (0-1)   - Cantidad chorus" >>>;
<<< "  /reverb (0-1)   - Cantidad reverb" >>>;
<<< "" >>>;
<<< "Para efecto T-Pain extremo:" >>>;
<<< "  Cambia linea 18: 0.01 => float CORRECTION_SPEED;" >>>;
<<< "" >>>;

while (true) {
    1::second => now;
}