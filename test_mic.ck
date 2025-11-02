// Test de entrada de micrófono
// Muestra niveles de energía y estado de la señal

adc => Gain input => blackhole;

// FFT para análisis
input => FFT fft => blackhole;
512 => int FFT_SIZE;
FFT_SIZE => fft.size;
Windowing.hann(FFT_SIZE) => fft.window;

0.0 => float energy;
0.0 => float noiseFloor;

// Calibrar ruido de fondo
<<< "Calibrando ruido de fondo (2 segundos)..." >>>;
0.0 => float sum;
for (0 => int i; i < 20; i++) {
    100::ms => now;
    
    fft.upchuck() @=> UAnaBlob blob;
    0.0 => float e;
    for (0 => int j; j < FFT_SIZE/2; j++) {
        blob.fval(j) => float m;
        m * m +=> e;
    }
    e / (FFT_SIZE/2) => e;
    sum + e => sum;
}
sum / 20 => noiseFloor;

<<< "Calibración completada:" >>>;
<<< "Nivel de ruido:", noiseFloor >>>;
<<< "" >>>;
<<< "Monitoreando entrada..." >>>;
<<< "(Ctrl+C para detener)" >>>;
<<< "" >>>;

// Monitorear entrada
while (true) {
    fft.upchuck() @=> UAnaBlob blob;
    
    0.0 => float e;
    for (0 => int i; i < FFT_SIZE/2; i++) {
        blob.fval(i) => float m;
        m * m +=> e;
    }
    e / (FFT_SIZE/2) => e;
    energy * 0.7 + e * 0.3 => energy;
    
    <<< "Energía:", energy, "| Ratio sobre ruido:", energy/noiseFloor >>>;
    
    100::ms => now;
}