"""Synthesize the sound effects track for each short (no music: pick a track in the YouTube/Instagram app).

usage: python sfx.py            -> assets/shorts/sfx1.wav, sfx2.wav, sfx3.wav (48 kHz stereo)
Event times are seconds of the final video and follow the timeline in shorts.html.
"""
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SR = 48000
rng = np.random.default_rng(7)


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1) * np.exp(-t / decay)


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be an array (Hz per sample)."""
    a = np.exp(-2 * np.pi * np.broadcast_to(cutoff, x.shape) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def sine(freq, n):
    return np.sin(2 * np.pi * np.cumsum(np.broadcast_to(freq, (n,))) / SR)


def key():
    n = int(.035 * SR)
    noise = rng.standard_normal(n)
    body = noise - lowpass(noise, 1800)
    return (body * env(n, .0005, .006) * .5 + sine(1900 + rng.uniform(-200, 200), n) * env(n, .0003, .004) * .25)


def tap():
    n = int(.12 * SR)
    f = 900 * np.exp(-np.arange(n) / SR / .03) + 180
    click = np.pad(key(), (0, n - int(.035 * SR)))
    return sine(f, n) * env(n, .001, .045) * .9 + click * .6


def pop(lo=420, hi=980, length=.09, vol=.55):
    n = int(length * SR)
    f = lo + (hi - lo) * (1 - np.exp(-np.arange(n) / SR / .02))
    return sine(f, n) * env(n, .002, length / 3) * vol


def chime():
    n = int(.9 * SR)
    out = np.zeros(n)
    for start, base in ((0, 1318.5), (.085, 1975.5)):
        k = int(start * SR)
        m = n - k
        tone = sum(a * sine(base * h, m) for h, a in ((1, 1), (2, .35), (3, .12)))
        out[k:] += tone * env(m, .002, .22) * .32
    return out


def whoosh(length=.55, lo=300, hi=5000, vol=.5, rising=True):
    n = int(length * SR)
    x = np.linspace(0, 1, n)
    shape = x if rising else 1 - x
    cut = lo + (hi - lo) * shape ** 2
    noise = rng.standard_normal(n)
    band = lowpass(noise, cut) - lowpass(noise, cut * .25)
    amp = np.sin(np.pi * x) ** 1.5 if not rising else x ** 2 * (1 - x) ** .3 * 2.2
    return band * amp * vol


def hit():
    n = int(1.2 * SR)
    f = 110 * np.exp(-np.arange(n) / SR / .08) + 48
    boom = sine(f, n) * env(n, .002, .28)
    noise = rng.standard_normal(n)
    crack = (noise - lowpass(noise, 3000)) * env(n, .0005, .02) * .4
    return (boom * .9 + crack)


def shimmer():
    n = int(1.3 * SR)
    out = np.zeros(n)
    for i, f in enumerate((1568, 2093, 2637, 3136)):
        k = int(i * .06 * SR)
        out[k:] += sine(f, n - k) * env(n - k, .003, .35) * .1
    return out


def build(D, events):
    out = np.zeros((int(D * SR), 2))
    for t, snd, pan in events:
        k = int(t * SR)
        s = snd[: len(out) - k]
        out[k:k + len(s), 0] += s * (1 - max(pan, 0))
        out[k:k + len(s), 1] += s * (1 + min(pan, 0))
    peak = np.abs(out).max()
    out *= 10 ** (-3 / 20) / peak
    return out


def hook(n_words):
    return [(.05 + i * .12, pop(380 + i * 60, 900 + i * 90, .1, .5), 0) for i in range(n_words)] + [
        (.45, pop(1200, 1600, .05, .2), 0), (.9, whoosh(.5, 400, 7000, .55), 0)]


def outro(t):
    return [(t - .05, whoosh(.45, 300, 6000, .5, rising=False), 0), (t + .15, hit(), 0), (t + .2, shimmer(), 0)]


def swoosh(t, vol=.25):
    return (t, whoosh(.4, 500, 4000, vol, rising=False), 0)


def short1():
    keys = np.linspace(1.1 + 66 / 30, 1.1 + 157 / 30, 32) + rng.uniform(-.012, .012, 32)
    ev = hook(3) + [(1.6, tap(), .2), (2.33, tap(), .2), swoosh(2.7)]
    ev += [(t, key() * rng.uniform(.6, 1), rng.uniform(-.2, .2)) for t in keys]
    ev += [(5.08, pop(600, 1300, .08, .45), 0), (6.37, pop(700, 1500, .08, .5), 0)]
    ev += [(8.6, tap(), .3), (9.0, chime(), 0), swoosh(8.6)] + outro(11.4)
    return build(13.6, ev)


def short2():
    ev = hook(4) + [swoosh(1.7), (2.77, tap(), -.2), (3.2, chime(), 0), (4.93, tap(), -.2), (5.5, chime(), 0),
                    swoosh(5.55, .3)] + outro(8.5)
    return build(10.7, ev)


def short3():
    ev = hook(5) + [(1.25, whoosh(.4, 600, 5000, .3), 0), swoosh(2.2), swoosh(2.9, .3), (3.4, pop(500, 1100, .1, .45), 0),
                    swoosh(4.6), (6.95, tap(), -.3), (7.33, chime(), 0), swoosh(7.5), (9.1, whoosh(.4, 600, 5000, .3), 0),
                    swoosh(9.9), swoosh(10.3, .3), (10.8, pop(500, 1100, .1, .45), 0)] + outro(12.4)
    return build(14.6, ev)


def write(path, data):
    pcm = (np.clip(data, -1, 1) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    for n, fn in ((1, short1), (2, short2), (3, short3)):
        write(HERE / "assets" / "shorts" / f"sfx{n}.wav", fn())
        print(f"sfx{n}.wav")
