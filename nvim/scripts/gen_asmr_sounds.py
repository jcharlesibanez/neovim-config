#!/usr/bin/env python3
"""Synthesize the :ASMR keyboard sounds into nvim/sounds/asmr/<1-5>/.

Each keystroke is built from a few short layers, which is roughly how a real switch sounds:
  click  - a very short burst of high-pitched noise (the switch leaf / click jacket)
  body   - band-passed noise ringing at the keycap/case resonance (most of the "tone")
  thump  - a low sine that drops in pitch (the key bottoming out on the plate)
  rattle - optional second transient (stabilizer on space/enter)
  up     - a faint upstroke ~70 ms later (the key returning)
Only the stdlib is used so it runs anywhere: python3 gen_asmr_sounds.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds", "asmr")

PROFILES = {
    1: dict(name="thock", click=(3000, 0.15, 0.002), body=(700, 1.0, 0.018, 4), thump=(160, 0.8, 0.025), up=0.15, lp=None),
    2: dict(name="clicky", click=(5500, 1.0, 0.0015), click2=(4500, 0.8, 0.006), body=(1800, 0.5, 0.008, 5),
            thump=(300, 0.2, 0.012), up=0.4, lp=None),
    3: dict(name="tactile", click=(2500, 0.35, 0.002), body=(1100, 0.9, 0.012, 4), thump=(220, 0.4, 0.018), up=0.2, lp=None),
    4: dict(name="typewriter", click=(3500, 1.0, 0.003), body=(900, 0.9, 0.030, 3), thump=(120, 0.6, 0.02),
            ring=((2400, 3100), 0.15, 0.06), up=0.1, lp=None),
    5: dict(name="marble", click=(2000, 0.05, 0.002), body=(500, 1.0, 0.014, 3), thump=(110, 1.0, 0.03), up=0.1, lp=2500),
}


def bandpass(x, f, q):
    # RBJ biquad band-pass (0 dB peak): isolates the resonance that gives each layer its pitch.
    w0 = 2 * math.pi * f / SR
    alpha = math.sin(w0) / (2 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    y, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for s in x:
        o = (b0 * s + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, s, y1, o
        y.append(o)
    return y


def lowpass(x, f):
    a = math.exp(-2 * math.pi * f / SR)
    y, prev = [], 0.0
    for s in x:
        prev = (1 - a) * s + a * prev
        y.append(prev)
    return y


def noise_burst(n, tau, start=0):
    return [0.0] * start + [random.uniform(-1, 1) * math.exp(-i / (tau * SR)) for i in range(n - start)]


def add(dst, src, gain):
    for i, s in enumerate(src[: len(dst)]):
        dst[i] += s * gain


def keystroke(p, pitch=1.0, length=0.12, rattle=False, bell=False):
    n = int(length * SR)
    out = [0.0] * n
    j = lambda: random.uniform(0.94, 1.06)  # small per-variant jitter so repeats don't sound robotic

    f, amp, tau = p["click"]
    add(out, bandpass(noise_burst(n, tau), f * j(), 2), amp * 3)
    if "click2" in p:
        f, amp, delay = p["click2"]
        add(out, bandpass(noise_burst(n, 0.0015, int(delay * SR)), f * j(), 2), amp * 3)

    f, amp, tau, q = p["body"]
    add(out, bandpass(noise_burst(n, tau), f * pitch * j(), q), amp * 4)

    f, amp, tau = p["thump"]
    f *= pitch * j()
    phase = 0.0
    for i in range(n):
        phase += 2 * math.pi * f * (1 - 0.3 * min(1, i / (0.03 * SR))) / SR  # pitch drop
        out[i] += math.sin(phase) * math.exp(-i / (tau * SR)) * amp

    if "ring" in p:
        freqs, amp, tau = p["ring"]
        for fr in freqs:
            for i in range(n):
                out[i] += math.sin(2 * math.pi * fr * j() * i / SR) * math.exp(-i / (tau * SR)) * amp

    if rattle:
        add(out, bandpass(noise_burst(n, 0.004, int(0.009 * SR)), 1400 * j(), 3), 1.6)

    up_at = int(0.07 * SR)
    if p["up"] and up_at < n:
        add(out, bandpass(noise_burst(n, 0.004, up_at), p["body"][0] * 1.3 * pitch, 4), p["up"] * 3)

    if bell:
        extra = int(0.6 * SR)
        out += [0.0] * extra
        for i in range(len(out)):
            t = i / SR
            out[i] += (math.sin(2 * math.pi * 2093 * t) + 0.5 * math.sin(2 * math.pi * 4186 * t)) * math.exp(-t / 0.35) * 0.35

    if p["lp"]:
        out = lowpass(out, p["lp"])

    peak = max(abs(s) for s in out) or 1
    fade = int(0.0003 * SR)
    return [s / peak * 0.8 * min(1, i / fade if fade else 1) for i, s in enumerate(out)]


def write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


def main():
    random.seed(7)  # reproducible sounds
    for num, p in PROFILES.items():
        d = os.path.join(OUT, str(num))
        os.makedirs(d, exist_ok=True)
        for v in range(1, 5):
            write(os.path.join(d, f"key{v}.wav"), keystroke(p))
        write(os.path.join(d, "space.wav"), keystroke(p, pitch=0.75, length=0.14, rattle=True))
        write(os.path.join(d, "enter.wav"), keystroke(p, pitch=0.85, length=0.14, rattle=True, bell=(num == 4)))
        write(os.path.join(d, "backspace.wav"), keystroke(p, pitch=1.1))
        print(f"{num}: {p['name']}")


if __name__ == "__main__":
    main()
