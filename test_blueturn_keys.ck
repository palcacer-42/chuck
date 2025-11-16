// Test what keys the BlueTurn sends
// Press the BlueTurn buttons and see what key codes appear

<<< "=== BlueTurn Key Tester ===" >>>;
<<< "Press the BlueTurn buttons (or any keys)" >>>;
<<< "Press 'q' to quit\n" >>>;

KBHit kb;

while (true)
{
    kb => now;
    
    while (kb.more())
    {
        kb.getchar() => int k;
        
        if (k == 'q') 
        {
            <<< "Exiting..." >>>;
            me.exit();
        }
        
        // Show the ASCII code
        if (k >= 32 && k <= 126)
        {
            <<< "Key pressed: ASCII", k, "(printable character)" >>>;
        }
        else
        {
            <<< "Key pressed: ASCII", k, "(special/control character)" >>>;
        }
    }
}
