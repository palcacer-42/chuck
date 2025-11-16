// Test BlueTurn using HID (Human Interface Device)
// This will read directly from the BlueTurn keyboard device

Hid hid;
HidMsg msg;

<<< "=== Attempting to open BlueTurn (HID keyboard device 0) ===" >>>;

// Try to open the BlueTurn (device 0 based on chuck --probe)
if (!hid.openKeyboard(0))
{
    <<< "Error: Cannot open keyboard device 0 (BlueTurn)" >>>;
    <<< "Try running: chuck --probe" >>>;
    me.exit();
}

<<< "✓ Opened:", hid.name() >>>;
<<< "Press BlueTurn buttons (Ctrl+C to quit)\n" >>>;

// Read from the device
while (true)
{
    hid => now;
    
    while (hid.recv(msg))
    {
        // Only show key down events (not key up)
        if (msg.isButtonDown())
        {
            <<< "🦶 Button pressed! - Which:", msg.which, "Key:", msg.key, "ASCII:", msg.ascii >>>;
        }
    }
}
