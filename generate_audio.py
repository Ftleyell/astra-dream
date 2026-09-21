"""
Procedural Audio & Music Synthesizer for Astra Dream
Generates 16-bit 44.1kHz WAV files for SFX and loopable BGM.
"""
import math
import wave
import struct
import random

SAMPLE_RATE = 44100

def write_wav(filename, samples, sample_rate=SAMPLE_RATE, channels=1):
    # Normalize to avoid clipping
    max_val = max(abs(s) for s in samples) if samples else 0.0
    if max_val > 0.98:
        scale = 0.95 / max_val
        samples = [s * scale for s in samples]
    
    with wave.open(filename, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2) # 16-bit
        wf.setframerate(sample_rate)
        raw_bytes = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            int_val = int(clamped * 32767.0)
            raw_bytes.extend(struct.pack("<h", int_val))
        wf.writeframes(raw_bytes)
    print(f"Generated {filename} ({len(samples)/sample_rate:.2f}s)")

# --- SFX GENERATORS ---

def gen_laser_fire():
    duration = 0.20
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-14.0 * t) # Rapid exponential decay
        # Downward pitch bend from 1100Hz to 160Hz
        freq = 1100.0 * math.exp(-12.0 * t) + 160.0
        phase = 2.0 * math.pi * freq * t
        # Sine + 3rd harmonic for sci-fi bite
        val = (math.sin(phase) + 0.35 * math.sin(phase * 3.0)) * env
        samples.append(val * 0.75)
    write_wav("assets/audio/sfx/laser_fire.wav", samples)

def gen_missile_fire():
    duration = 0.32
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    noise_state = 0.0
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = (t / 0.04) if t < 0.04 else math.exp(-6.0 * (t - 0.04))
        # Pitch rises then levels off (120Hz to 360Hz)
        freq = 120.0 + 240.0 * (1.0 - math.exp(-15.0 * t))
        tone = math.sin(2.0 * math.pi * freq * t)
        # Filtered white noise for rocket exhaust rumble
        white = (random.random() * 2.0 - 1.0)
        noise_state = noise_state * 0.8 + white * 0.2
        val = (tone * 0.5 + noise_state * 0.5) * env
        samples.append(val * 0.7)
    write_wav("assets/audio/sfx/missile_fire.wav", samples)

def gen_explosion():
    duration = 0.55
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    noise_state = 0.0
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-7.0 * t)
        # Deep sub boom (95Hz down to 25Hz)
        freq = 95.0 * math.exp(-8.0 * t) + 25.0
        sub = math.sin(2.0 * math.pi * freq * t)
        # Crunchy noise blast
        white = (random.random() * 2.0 - 1.0)
        noise_state = noise_state * 0.7 + white * 0.3
        val = (sub * 0.6 + noise_state * 0.4) * env
        # Slight saturation / distortion
        val = math.tanh(val * 1.8)
        samples.append(val * 0.85)
    write_wav("assets/audio/sfx/explosion.wav", samples)

def gen_exp_pickup():
    # Crystal chime (C6 = 1046.5Hz, E6 = 1318.5Hz, G6 = 1567.98Hz)
    duration = 0.25
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-10.0 * t)
        # Bell chime
        t1 = math.sin(2.0 * math.pi * 1046.5 * t)
        t2 = math.sin(2.0 * math.pi * 1567.98 * t) * 0.6
        t3 = math.sin(2.0 * math.pi * 2093.0 * t) * 0.3
        val = (t1 + t2 + t3) * env
        samples.append(val * 0.6)
    write_wav("assets/audio/sfx/exp_pickup.wav", samples)

def gen_dash():
    duration = 0.22
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    filter_state = 0.0
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / duration)) # Bell envelope
        # Filtered resonant swoosh
        white = (random.random() * 2.0 - 1.0)
        filter_state = filter_state * 0.85 + white * 0.15
        pitch = 300.0 + 400.0 * math.sin(math.pi * (t / duration))
        tone = math.sin(2.0 * math.pi * pitch * t)
        val = (filter_state * 0.7 + tone * 0.3) * env
        samples.append(val * 0.75)
    write_wav("assets/audio/sfx/dash.wav", samples)

def gen_bomb():
    duration = 0.95
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    noise_state = 0.0
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Reverse suck in (0-0.2s) followed by massive explosion (0.2s - 0.95s)
        if t < 0.20:
            env = (t / 0.20) ** 2.0
            freq = 60.0 + 350.0 * (t / 0.20)
            val = math.sin(2.0 * math.pi * freq * t) * env * 0.5
        else:
            t_exp = t - 0.20
            env = math.exp(-4.5 * t_exp)
            sub = math.sin(2.0 * math.pi * 42.0 * t) * 0.8
            white = (random.random() * 2.0 - 1.0)
            noise_state = noise_state * 0.65 + white * 0.35
            val = (sub + noise_state * 0.7) * env
            val = math.tanh(val * 2.0)
        samples.append(val * 0.85)
    write_wav("assets/audio/sfx/bomb.wav", samples)

def gen_player_hit():
    duration = 0.18
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-12.0 * t)
        # Warning square-wave clank
        sq1 = 1.0 if math.sin(2.0 * math.pi * 180.0 * t) > 0.0 else -1.0
        sq2 = 1.0 if math.sin(2.0 * math.pi * 230.0 * t) > 0.0 else -1.0
        val = (sq1 * 0.5 + sq2 * 0.5) * env
        samples.append(val * 0.6)
    write_wav("assets/audio/sfx/player_hit.wav", samples)

def gen_ui_click():
    duration = 0.04
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-60.0 * t)
        val = math.sin(2.0 * math.pi * 1400.0 * t) * env
        samples.append(val * 0.5)
    write_wav("assets/audio/sfx/ui_click.wav", samples)

# --- MUSIC GENERATORS (LOOPABLE) ---

def gen_combat_music():
    # 128 BPM -> 1 beat = 60/128 = 0.46875s
    # 4 bars of 4/4 = 16 beats = 7.5s (exact integer sample count for seamless looping)
    bpm = 128.0
    beat_dur = 60.0 / bpm
    total_beats = 16
    total_dur = total_beats * beat_dur # 7.5 seconds
    n_samples = int(total_dur * SAMPLE_RATE)
    samples = [0.0] * n_samples

    # Root chord progression across 4 bars:
    # Bar 1: F# minor (F#2 = 92.50 Hz)
    # Bar 2: D major (D2 = 73.42 Hz)
    # Bar 3: A major (A2 = 110.0 Hz)
    # Bar 4: C# minor (C#2 = 69.30 Hz)
    roots = [92.50, 73.42, 110.0, 69.30]

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        beat_idx = t / beat_dur
        bar_idx = int(beat_idx / 4.0) % 4
        root_freq = roots[bar_idx]

        # 1. Kick Drum on every beat (4-on-the-floor)
        beat_phase = beat_idx % 1.0
        kick_env = math.exp(-22.0 * beat_phase)
        kick_freq = 140.0 * math.exp(-30.0 * beat_phase) + 38.0
        kick = math.sin(2.0 * math.pi * kick_freq * beat_phase * beat_dur) * kick_env * 0.7

        # 2. Snare / Clap on beats 2 and 4 (beat_idx 1, 3, 5, 7, etc.)
        in_snare = int(beat_idx) % 2 == 1
        snare_env = math.exp(-16.0 * beat_phase) if in_snare else 0.0
        snare_noise = (random.random() * 2.0 - 1.0) * snare_env * 0.45

        # 3. Offbeat Hi-hat (8th note offbeat)
        eighth_phase = (beat_idx * 2.0) % 1.0
        is_offbeat = int(beat_idx * 2.0) % 2 == 1
        hihat_env = math.exp(-40.0 * eighth_phase) if is_offbeat else 0.0
        hihat = (random.random() * 2.0 - 1.0) * hihat_env * 0.25

        # 4. Driving Cyberpunk 16th-note Bassline
        sixteenth_idx = int(beat_idx * 4.0)
        sixteenth_phase = (beat_idx * 4.0) % 1.0
        # Octave bounce on 16ths
        oct_mult = 1.0 if sixteenth_idx % 2 == 0 else 2.0
        bass_freq = root_freq * oct_mult
        bass_env = math.exp(-10.0 * sixteenth_phase)
        # Sawtooth / rich bass
        b_p = (t * bass_freq) % 1.0
        saw = (2.0 * b_p - 1.0)
        bass = saw * bass_env * 0.35

        # 5. Arpeggiator Lead (High sci-fi arps: Root, Minor 3rd, 5th, Octave)
        arp_scale = [1.0, 1.1892, 1.4983, 2.0, 2.3784, 2.0, 1.4983, 1.1892]
        arp_note = arp_scale[sixteenth_idx % 8]
        lead_freq = root_freq * 4.0 * arp_note
        lead_env = math.exp(-12.0 * sixteenth_phase)
        lead = math.sin(2.0 * math.pi * lead_freq * t) * lead_env * 0.22

        total = kick + snare_noise + hihat + bass + lead
        samples[i] = total * 0.70

    write_wav("assets/audio/music_combat.wav", samples)

def gen_menu_music():
    # Ambient, ethereal cosmic synth loop (10.0 seconds, seamless)
    dur = 10.0
    n_samples = int(dur * SAMPLE_RATE)
    samples = [0.0] * n_samples

    # Soft ambient chord frequencies: Am7 (A3=220, C4=261.6, E4=329.6, G4=392)
    chords = [
        [220.0, 261.63, 329.63, 392.00],  # Am7
        [174.61, 220.0, 261.63, 329.63]   # Fmaj7
    ]

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        chord = chords[0] if t < 5.0 else chords[1]
        t_chord = t % 5.0
        # Smooth pad crossfade envelope
        env = math.sin(math.pi * (t_chord / 5.0))
        
        pad = 0.0
        for f in chord:
            # Subtle chorused sine wave
            s1 = math.sin(2.0 * math.pi * f * t)
            s2 = math.sin(2.0 * math.pi * (f * 1.003) * t) * 0.5
            pad += (s1 + s2)
        pad = (pad / len(chord)) * env * 0.45

        # Gentle sub pulse (55Hz)
        sub = math.sin(2.0 * math.pi * 55.0 * t) * (0.15 + 0.05 * math.sin(2.0 * math.pi * 0.5 * t))
        
        # Soft shimmer / crystal droplet every 2.5s
        shimmer_t = t % 2.5
        shimmer_env = math.exp(-8.0 * shimmer_t)
        shimmer = math.sin(2.0 * math.pi * 1760.0 * shimmer_t) * shimmer_env * 0.12

        samples[i] = (pad + sub + shimmer) * 0.75

    write_wav("assets/audio/music_menu.wav", samples)

if __name__ == "__main__":
    print("Generating SFX...")
    gen_laser_fire()
    gen_missile_fire()
    gen_explosion()
    gen_exp_pickup()
    gen_dash()
    gen_bomb()
    gen_player_hit()
    gen_ui_click()

    print("Generating Music Tracks...")
    gen_combat_music()
    gen_menu_music()
    print("ALL AUDIO GENERATED SUCCESSFULLY!")
