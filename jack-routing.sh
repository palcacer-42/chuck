jack_connect "mod-monitor:out_1" "ChucK:inport 0"
jack_connect "mod-monitor:out_2" "ChucK:inport 1"

jack_disconnect "system:capture_1" "ChucK:inport 0"
jack_disconnect "system:capture_2" "ChucK:inport 1"
