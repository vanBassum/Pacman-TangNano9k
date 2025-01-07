# Pac-Man on TangNano

Forked from:  
[https://github.com/harbaum/Pacman-TangNano9k](https://github.com/harbaum/Pacman-TangNano9k)

I decided to use different hardware for this project since I had an NHD 7.0 800x480 RGB display lying around in my parts bin.

### Key Changes:
- **Video Output:** The project now uses an 800x480 RGB display.
- **Audio Output:** Sigma-Delta modulation is implemented to generate audio output.

### Configuration Adjustments:
Ensure that the following settings are enabled for proper functionality:
1. Go to **Project > Configuration > Dual-purpose pin**.
2. Check the **Use SSPI as regular IO** checkbox.

For the audio output, I used a 1k2 resistor and a 3n3 capacitor in the low-pass filter to make the audio analog.


