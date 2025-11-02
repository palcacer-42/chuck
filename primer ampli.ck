/ ================================================
// MONITOR DE MICRÓFONO CON EFECTOS EN TIEMPO REAL
// ================================================
// Presiona Ctrl+C para detener el programa

// Cadena de procesamiento de audio
adc => Gain inputGain => LPF filter => Delay delay => NRev reverb => Gain master => dac;

// Feedback del delay
delay => Gain feedback => delay;

// Configuración inicial de parámetros
<<< "=== MONITOR DE MICRÓFONO ACTIVADO ===" >>>;
<<< "Configurando efectos..." >>>;

// Volumen de entrada (ajusta según tu micrófono)
1 => inputGain.gain;

// Filtro paso-bajo (elimina frecuencias altas)
8000 => filter.freq;  // Frecuencia de corte en Hz

// Delay (eco)
30::ms => delay.max => delay.delay;  // 300ms de retardo
0.3 => feedback.gain;  // Retroalimentación del delay

// Reverb (reverberación)
0.60 => reverb.mix;  // 15% wet, 85% dry

// Volumen maestro de salida
2 => master.gain;

<<< "¡Listo! Habla o haz sonidos..." >>>;
<<< "" >>>;
<<< "Parámetros actuales:" >>>;
<<< "- Ganancia de entrada:", inputGain.gain() >>>;
<<< "- Filtro paso-bajo:", filter.freq(), "Hz" >>>;
<<< "- Tiempo de delay:", delay.delay() / 1::ms, "ms" >>>;
<<< "- Feedback del delay:", feedback.gain() >>>;
<<< "- Mezcla de reverb:", reverb.mix() >>>;
<<< "- Volumen maestro:", master.gain() >>>;
<<< "" >>>;

// Medidor de nivel simple
fun void meterLevel() {
    while(true) {
        // Cada segundo muestra el nivel aproximado
        1::second => now;
        
        // Aquí podrías agregar análisis más sofisticado
        <<< "Procesando audio... (tiempo:", now/1::second, "s)" >>>;
    }
}

// Lanzar el medidor en un shred paralelo
spork ~ meterLevel();

// === MODULACIÓN AUTOMÁTICA (opcional) ===
// Descomentar para efectos dinámicos


fun void modulateEffects() {
    SinOsc lfo => blackhole;
    0.2 => lfo.freq;  // Oscilación lenta
    
    while(true) {
        // Modula el mix del reverb
        0.15 + (lfo.last() * 0.1) => reverb.mix;
        
        // Modula el filtro
        5000 + (lfo.last() * 3000) => filter.freq;
        
        10::ms => now;
    }
}

spork ~ modulateEffects();


// Bucle principal - mantiene el programa corriendo
while(true) {
    1::second => now;
    }