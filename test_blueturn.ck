// Quick BlueTurn MIDI tester
// Shows what MIDI messages your buttons send

MidiIn min;
MidiMsg msg;

<<< "\n=== Scanning for MIDI devices ===" >>>;
<<< "If you see your BlueTurn listed, note its device number\n" >>>;

// Try to list devices - this will print to console
min.printerr();

<<< "\n====================================\n" >>>;

<<< "Enter the device number for your BlueTurn: " >>>;

// Simple wait for user to see the list
// In practice, you'd enter this as a command line argument
// For now, let's just try device 0 as default
0 => int blueturnDevice;

// If you have multiple devices, run with: chuck test_blueturn.ck:1
// (where 1 is your device number)
if (me.args() > 0)
{
    Std.atoi(me.arg(0)) => blueturnDevice;
}

if (!min.open(blueturnDevice))
{
    <<< "Cannot open device", blueturnDevice >>>;
    me.exit();
}

<<< "\n✓ Listening to:", min.name() >>>;
<<< "\nPress your BlueTurn buttons now!" >>>;
<<< "Watch for the MIDI note numbers..." >>>;
<<< "(Press Ctrl+C to stop)\n" >>>;

while (true)
{
    min => now;
    
    while (min.recv(msg))
    {
        // Note On (144/0x90)
        if (msg.data1 == 144 && msg.data3 > 0)
        {
            <<< "🔵 Button pressed! → Note:", msg.data2, "Velocity:", msg.data3 >>>;
        }
        // Note Off (128/0x80) or Note On with velocity 0
        else if (msg.data1 == 128 || (msg.data1 == 144 && msg.data3 == 0))
        {
            <<< "⚪ Button released → Note:", msg.data2 >>>;
        }
        // Other MIDI messages
        else
        {
            <<< "MIDI → Status:", msg.data1, "Data1:", msg.data2, "Data2:", msg.data3 >>>;
        }
    }
}
