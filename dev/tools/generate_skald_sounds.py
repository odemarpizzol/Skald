"""Generate original, sample-free Skald notice sounds with simple physical-model synthesis.

Outputs 4 variants for each sound and a selected take into output/sound-art/.
No external samples or sound libraries are used; only NumPy and the Python stdlib.
"""
from pathlib import Path
import math
import struct
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "sound-art"
VARIANTS = OUT / "variants"
SR = 44100


def env(n, attack=0.008, release=0.12):
    t = np.arange(n) / SR
    e = np.ones(n, dtype=np.float64)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] *= np.linspace(0, 1, a, endpoint=True)
    e[-r:] *= np.linspace(1, 0, r, endpoint=True) ** 1.8
    return e


def bell(freq, seconds, amp=0.3, seed=1, warm=1.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    # Inharmonic, quickly decaying modes mimic a small hand bell without a sharp ring.
    ratios = (1.0, 2.01, 2.72, 4.08, 5.43)
    weights = (1.0, 0.42, 0.22, 0.105, 0.05)
    decays = (1.8, 1.05, 0.68, 0.43, 0.30)
    phase = np.random.default_rng(seed).uniform(-0.02, 0.02, len(ratios))
    y = np.zeros(n, dtype=np.float64)
    for i, (ratio, weight, decay) in enumerate(zip(ratios, weights, decays)):
        f = freq * ratio * (1 + phase[i])
        y += weight * np.sin(2 * np.pi * f * t + phase[i]) * np.exp(-t / (decay * warm))
    y *= env(n, 0.002, min(0.12, seconds * 0.22))
    return amp * y


def pluck(freq, seconds, amp=0.25, seed=1, damping=0.996, brightness=0.7):
    # Karplus-Strong string: a short noise burst recirculates through a two-sample average.
    n = int(seconds * SR)
    delay = max(2, int(SR / freq))
    rng = np.random.default_rng(seed)
    ring = rng.uniform(-1, 1, delay + 1).astype(np.float64)
    ring *= np.linspace(1.0, 0.25, delay + 1)
    y = np.empty(n, dtype=np.float64)
    for i in range(n):
        j = i % delay
        nxt = (j + 1) % delay
        ring[j] = damping * (0.5 * (ring[j] + ring[nxt]))
        y[i] = ring[j]
    # Blend a little smooth body resonance into the pluck; avoids brittle synthetic twang.
    t = np.arange(n) / SR
    body = (np.sin(2*np.pi*freq*2*t) * np.exp(-t/0.32) * 0.11
            + np.sin(2*np.pi*freq*3.01*t) * np.exp(-t/0.18) * 0.035)
    y = brightness * y + body
    y *= env(n, 0.003, min(0.14, seconds * 0.25))
    peak = np.max(np.abs(y)) or 1
    return amp * y / peak


def filtered_rustle(seconds, amp=0.07, seed=1, color=0.82):
    n = int(seconds * SR)
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, 1, n)
    # Two short moving-average filters take the edge off white noise, like paper/page friction.
    win1 = np.ones(18) / 18
    win2 = np.ones(50) / 50
    soft = np.convolve(noise, win1, mode="same") * (1-color) + np.convolve(noise, win2, mode="same") * color
    t = np.arange(n) / SR
    shape = np.exp(-t / max(0.035, seconds * 0.35)) * np.minimum(1, t / 0.006)
    peak = np.max(np.abs(soft)) or 1
    return amp * soft / peak * shape


def wood_tap(seconds=0.2, amp=0.2, freq=245, seed=1):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    transient = rng.normal(0, 1, n) * np.exp(-t / 0.008) * 0.12
    reson = (np.sin(2*np.pi*freq*t) * np.exp(-t/0.045)
             + 0.42*np.sin(2*np.pi*freq*2.65*t) * np.exp(-t/0.028))
    y = (reson + transient) * env(n, 0.001, min(0.04, seconds * 0.3))
    return amp * y / (np.max(np.abs(y)) or 1)


def mix(parts, seconds):
    n = int(seconds * SR)
    y = np.zeros(n, dtype=np.float64)
    for start, sound in parts:
        at = int(start * SR)
        if at >= n:
            continue
        end = min(n, at + len(sound))
        y[at:end] += sound[:end-at]
    # A gentle limiter preserves transients while preventing clipping.
    y = np.tanh(y * 1.1) / 1.1
    peak = np.max(np.abs(y)) or 1
    y *= 0.88 / peak
    return y


def make_notice(v):
    freqs = (587.33, 523.25, 659.25, 493.88)
    seconds = (0.76, 0.82, 0.68, 0.88)[v-1]
    f = freqs[v-1]
    rustle = filtered_rustle(0.16, amp=0.055 + 0.008*v, seed=100+v)
    strike = bell(f, seconds-0.02, amp=0.43, seed=200+v, warm=0.92+0.08*v)
    string = pluck(f*0.5, 0.46, amp=0.18, seed=300+v, damping=0.995+v*0.0005)
    return 0.72 * mix([(0.0, rustle), (0.018, strike), (0.026, string)], seconds)


def make_major(v):
    roots = ((392.0, 493.88, 587.33), (349.23, 440.0, 523.25),
             (415.30, 523.25, 659.25), (369.99, 466.16, 554.37))
    notes = roots[v-1]
    seconds = (1.26, 1.42, 1.18, 1.34)[v-1]
    parts = [(0.0, wood_tap(0.16, 0.15, 210+v*7, 400+v)),
             (0.025, filtered_rustle(0.20, 0.035, 500+v))]
    for i, f in enumerate(notes):
        start = 0.055 + i*0.17
        parts.append((start, pluck(f, seconds-start-0.03, amp=0.31 if i == 0 else 0.27,
                                   seed=600+v*7+i, damping=0.996, brightness=0.76)))
        parts.append((start+0.012, bell(f*2, min(0.48, seconds-start), amp=0.10 if i < 2 else 0.13,
                                        seed=700+v*9+i, warm=0.75)))
    return 0.92 * mix(parts, seconds)


def make_soft(v):
    seconds = (0.48, 0.56, 0.43, 0.52)[v-1]
    freq = (293.66, 261.63, 329.63, 277.18)[v-1]
    return 0.42 * mix([(0.0, wood_tap(0.15, 0.26, freq*0.78, 800+v)),
                (0.006, filtered_rustle(0.20, 0.085, 900+v, color=0.72)),
                (0.014, pluck(freq, seconds-0.02, amp=0.20, seed=1000+v, damping=0.991, brightness=0.48))], seconds)


def write_wav(path, samples):
    pcm = np.clip(samples, -1, 1)
    pcm = (pcm * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())


OUT.mkdir(parents=True, exist_ok=True)
VARIANTS.mkdir(parents=True, exist_ok=True)
makers = {"skald_notice": make_notice, "skald_major": make_major, "skald_soft": make_soft}
# The selected take is the cleanest, warm middle-ground design (variant 2).
for name, maker in makers.items():
    for variant in range(1, 5):
        samples = maker(variant)
        write_wav(VARIANTS / f"{name}_v{variant}.wav", samples)
        if variant == 2:
            write_wav(OUT / f"{name}.wav", samples)
print(f"Generated 12 variants and 3 selected WAVs in {OUT}")
