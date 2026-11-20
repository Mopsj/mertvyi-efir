#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Генератор плейсхолдерных звуков для «Мёртвого эфира».
Все файлы синтезируются процедурно (CC0, генератор — часть репозитория).
Запуск: python3 tools/make_sounds.py  (пишет в sounds/*.wav)
"""
import math
import random
import struct
import wave

SR = 22050
random.seed(7)

TWO_PI = 2.0 * math.pi


def write_wav(name, s, gain=1.0):
    peak = max(1e-9, max(abs(x) for x in s))
    k = min(1.0, 0.92 / peak) * gain
    with wave.open('sounds/%s.wav' % name, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for x in s:
            v = max(-1.0, min(1.0, x * k))
            frames += struct.pack('<h', int(v * 32767))
        w.writeframes(bytes(frames))
    print('  %-18s %.2fs' % (name, len(s) / SR))


def silence(dur):
    return [0.0] * int(dur * SR)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, x in enumerate(p):
            out[i] += x
    return out


def lowpass(s, cutoff):
    a = 1.0 - math.exp(-TWO_PI * cutoff / SR)
    y = 0.0
    out = []
    for x in s:
        y += a * (x - y)
        out.append(y)
    return out


def biquad_bandpass(s, f0, q):
    w0 = TWO_PI * f0 / SR
    alpha = math.sin(w0) / (2.0 * q)
    b0 = alpha
    b1 = 0.0
    b2 = -alpha
    a0 = 1.0 + alpha
    a1 = -2.0 * math.cos(w0)
    a2 = 1.0 - alpha
    b0 /= a0
    b1 /= a0
    b2 /= a0
    a1 /= a0
    a2 /= a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in s:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        out.append(y)
    return out


def env_exp(n, k):
    return [math.exp(-k * i / n) for i in range(n)]


def attack_decay(n, a):
    e = []
    for i in range(n):
        if i < a:
            e.append(i / max(1, a))
        else:
            e.append(math.exp(-3.0 * (i - a) / max(1, n - a)))
    return e


def noise(dur):
    return [random.uniform(-1, 1) for _ in range(int(dur * SR))]


def sweep_dur_to_n(f_from, f_to, n, wave_kind='sine'):
    ph = 0.0
    out = []
    for i in range(n):
        t = i / n
        f = f_from + (f_to - f_from) * t
        ph += TWO_PI * f / SR
        if wave_kind == 'sine':
            out.append(math.sin(ph))
        elif wave_kind == 'saw':
            out.append(2.0 * ((ph / TWO_PI) % 1.0) - 1.0)
    return out


# ---------------------------------------------------------------- лупы
def hum_room():
    n = int(6.0 * SR)
    s = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TWO_PI * 55 * t) + 0.55 * math.sin(TWO_PI * 110.7 * t)
             + 0.22 * math.sin(TWO_PI * 148 * t) + 0.12 * math.sin(TWO_PI * 210 * t))
        v *= 0.72 + 0.28 * math.sin(TWO_PI * 0.23 * t + 1.1)
        s.append(v * 0.4)
    write_wav('hum_room', lowpass(s, 900))


def hum_transformer():
    n = int(4.0 * SR)
    s = []
    for i in range(n):
        t = i / SR
        v = (math.sin(TWO_PI * 100 * t) + 0.4 * math.sin(TWO_PI * 120 * t)
             + 0.25 * math.sin(TWO_PI * 300 * t) + 0.12 * math.sin(TWO_PI * 500 * t))
        v *= 0.65 + 0.35 * math.sin(TWO_PI * 13 * t)
        s.append(v * 0.36)
    write_wav('hum_transformer', s)


def wind():
    n = int(8.0 * SR)
    s = noise(8.0)
    s = lowpass(lowpass(s, 350), 700)
    out = []
    walk = 0.3
    for i in range(n):
        if i % int(SR * 0.5) == 0:
            walk = min(1.0, max(0.15, walk + random.uniform(-0.35, 0.35)))
        t = i / SR
        out.append(s[i] * (0.35 + 0.65 * walk * (0.6 + 0.4 * math.sin(TWO_PI * 0.08 * t))))
    write_wav('wind', out, 1.6)


def radio_loop():
    n = int(4.0 * SR)
    s = biquad_bandpass(noise(4.0), 1700, 0.9)
    for _ in range(11):
        at = random.randint(0, n - 2000)
        amp = random.uniform(0.3, 1.0)
        dl = random.randint(80, 450)
        for i in range(dl):
            if at + i < n:
                s[at + i] += amp * math.exp(-14 * i / dl) * random.uniform(-1, 1)
    write_wav('radio_loop', lowpass(s, 4200), 1.1)


def node_hum():
    n = int(5.0 * SR)
    s = []
    for i in range(n):
        t = i / SR
        s.append(0.5 * (math.sin(TWO_PI * 396 * t) + 0.8 * math.sin(TWO_PI * 602 * t))
                 * (0.7 + 0.3 * math.sin(TWO_PI * 1.7 * t)))
    write_wav('node_hum', lowpass(s, 2600), 0.9)


def drone_dark():
    n = int(8.0 * SR)
    s = []
    for i in range(n):
        t = i / SR
        s.append(0.6 * math.sin(TWO_PI * 38 * t) + 0.5 * math.sin(TWO_PI * 42 * t)
                 + 0.3 * math.sin(TWO_PI * 57 * t))
    out = [x * (0.55 + 0.45 * math.sin(TWO_PI * 0.07 * (i / SR) + 0.4))
           for i, x in enumerate(s)]
    write_wav('drone_dark', lowpass(out, 200), 1.4)


def alarm():
    n = int(3.0 * SR)
    s = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 660 if int(t * 2) % 2 == 0 else 495
        ph += TWO_PI * f / SR
        v = 0.6 * math.sin(ph) + 0.3 * math.sin(2 * ph)
        s.append(v * 0.5)
    write_wav('alarm', lowpass(s, 1300))


def presence():
    n = int(4.0 * SR)
    s = []
    for i in range(n):
        t = i / SR
        s.append(0.20 * math.sin(TWO_PI * 12000 * t)
                 + 0.5 * math.sin(TWO_PI * 207 * t)
                 + 0.5 * math.sin(TWO_PI * 213 * t))
    out = [x * (0.5 + 0.5 * math.sin(TWO_PI * 0.5 * (i / SR))) for i, x in enumerate(s)]
    write_wav('presence', lowpass(out, 3000), 0.5)


# ------------------------------------------------------------ онешоты
def step(name, tone, thump, k, gain=1.0):
    n = int(0.30 * SR)
    nz = lowpass(noise(0.30), tone)
    th = [math.sin(TWO_PI * thump * (i / SR)) * math.exp(-26 * i / n) for i in range(n)]
    s = [nz[i] * math.exp(-18 * i / n) * 0.8 + th[i] * 0.9 for i in range(n)]
    write_wav(name, s, gain)


def clatter():
    s = silence(0.9)
    for at, lf, ring in ((0, 2600, 1900), (0.24, 2100, 3100), (0.55, 1500, 2400)):
        a = int(at * SR)
        imp = lowpass(noise(0.09), lf)
        for i, x in enumerate(imp):
            if a + i < len(s):
                s[a + i] += x * math.exp(-30 * i / len(imp)) * 0.9
        d = int(0.35 * SR)
        for i in range(d):
            t = i / SR
            if a + 60 + i < len(s):
                s[a + 60 + i] += 0.35 * math.sin(TWO_PI * ring * t) * math.exp(-9 * i / d)
    write_wav('clatter', s, 1.4)


def door_metal():
    n = int(1.6 * SR)
    screech = sweep_dur_to_n(1100, 320, n, 'sine')
    vib = [screech[i] * (0.6 + 0.4 * math.sin(TWO_PI * 7 * (i / SR)))
           for i in range(n)]
    body = lowpass(noise(1.6), 480)
    e_env = [(i / n) ** 0.7 for i in range(n)]
    tail = int(0.22 * SR)
    thud = lowpass(noise(0.22), 240)
    for i in range(tail):
        j = n - tail + i
        if j < n:
            body[j] += thud[i] * 2.2 + math.sin(TWO_PI * 72 * (i / SR)) * 1.4
    s = [vib[i] * 0.5 * (1.0 - e_env[i]) + body[i] * 0.8 for i in range(n)]
    write_wav('door_metal', s, 1.2)


def hatch():
    n = int(2.6 * SR)
    s = lowpass(noise(2.6), 160)
    for at in (0.0, 0.7, 1.45, 2.05):
        a = int(at * SR)
        d = int(0.28 * SR)
        burst = lowpass(noise(0.28), 300)
        for i in range(d):
            if a + i < n:
                s[a + i] += burst[i] * math.exp(-12 * i / d) * 1.6
                s[a + i] += math.sin(TWO_PI * 58 * (i / SR)) * math.exp(-10 * i / d) * 1.1
    g = int(1.3 * SR)
    for i in range(g):
        s[i] += 0.5 * math.sin(TWO_PI * (130 - 45 * i / g) * (i / SR)) * (i / g) ** 2
    write_wav('hatch', lowpass(s, 900), 1.3)


def pickup():
    n = int(0.16 * SR)
    s = lowpass(noise(0.16), 3000)
    for i in range(n):
        s[i] = s[i] * math.exp(-40 * i / n) * 0.7
        if i < int(0.06 * SR):
            s[i] += 0.5 * math.sin(TWO_PI * 1400 * (i / SR)) * math.exp(-30 * i / n)
    write_wav('pickup', s)


def fuse_install():
    n = int(1.2 * SR)
    s = lowpass(noise(1.2), 700)
    for at in (0.0, 0.12):
        a = int(at * SR)
        for i in range(int(0.1 * SR)):
            if a + i < n:
                s[a + i] += lowpass(noise(0.1), 400)[i] * math.exp(-24 * i / int(0.1 * SR)) * 1.6
    h = int(0.9 * SR)
    for i in range(h):
        t = i / SR
        f = 180 + 150 * (i / h)
        if 250 + i < n:
            s[250 + i] += 0.8 * math.sin(TWO_PI * f * t) * (i / h)
    snap = lowpass(noise(0.08), 2400)
    for i in range(len(snap)):
        j = int(1.05 * SR) + i
        if j < n:
            s[j] += snap[i] * math.exp(-40 * i / len(snap)) * 1.8
    write_wav('fuse_install', s, 1.2)


def node_on():
    n = int(3.5 * SR)
    s = []
    ph = ph2 = 0.0
    for i in range(n):
        t = i / n
        f = 160 + 380 * t
        ph += TWO_PI * f / SR
        ph2 += TWO_PI * (f * 1.02) / SR
        s.append((math.sin(ph) + 0.7 * math.sin(ph2)) * (0.25 + 0.75 * t))
    s = lowpass(s, 3200)
    click = lowpass(noise(0.1), 2000)
    for i in range(len(click)):
        j = int(3.35 * SR) + i
        if j < n:
            s[j] += click[i] * math.exp(-35 * i / len(click)) * 2.0
    write_wav('node_on', s, 1.2)


def drip():
    n = int(0.7 * SR)
    s = []
    ph = 0.0
    for i in range(int(0.05 * SR)):
        t = i / SR
        f = 1700 - 20000 * t
        ph += TWO_PI * max(300, f) / SR
        s.append(math.sin(ph) * math.exp(-60 * i / int(0.05 * SR)))
    s += silence(0.65)
    out = list(s)
    for at, amp in ((0.18, 0.5), (0.36, 0.24)):
        a = int(at * SR)
        for i in range(int(0.3 * SR)):
            if a + i < len(out):
                out[a + i] += s[i] * amp if i < len(s) else 0.0
    write_wav('drip', lowpass(out, 4000), 1.3)


def whisper():
    n = int(3.2 * SR)
    s = noise(3.2)
    out = []
    for i in range(n):
        t = i / n
        e = min(1.0, min(i, n - i) / (0.35 * n))
        e *= 0.55 + 0.45 * math.sin(TWO_PI * 0.9 * t)
        f1 = 320 + 420 * math.sin(TWO_PI * 0.55 * t)
        f2 = 1300 + 900 * math.sin(TWO_PI * 0.33 * t + 2.0)
        v = biquad_bandpass(s[max(0, i - 260):i + 1], max(120, f1), 3.0)[-1]
        v += 0.6 * biquad_bandpass(s[max(0, i - 260):i + 1], max(300, f2), 4.0)[-1]
        out.append(v * e)
    write_wav('whisper', lowpass(out, 2800), 1.6)


def mimic():
    n = int(3.6 * SR)
    # гласные: (F1, F2, F3) через участки: а → о → у → а
    F = [(730, 1090, 2440), (570, 840, 2410), (300, 870, 2240), (660, 1120, 2550)]
    src = []
    ph = 0.0
    for i in range(n):
        ph += TWO_PI * (95 + 4 * math.sin(TWO_PI * 5.2 * (i / SR))) / SR
        v = 1.0 if (ph % TWO_PI) < 0.35 else -0.35
        t = i / n
        seg = min(3, int(t * 4))
        u = (t * 4) % 1.0
        nxt = min(3, seg + 1)
        f1 = F[seg][0] + (F[nxt][0] - F[seg][0]) * u
        f2 = F[seg][1] + (F[nxt][1] - F[seg][1]) * u
        f3 = F[seg][2] + (F[nxt][2] - F[seg][2]) * u
        src.append((v, f1, f2, f3))
    dry = [v for (v, f1, f2, f3) in src]
    out = [0.0] * n
    for i in range(0, n, 240):
        w = min(480, n - i)
        for comp, qq, amp in ((1, 6.0, 1.0), (2, 7.0, 0.7), (3, 8.0, 0.4)):
            seg = [x[0] for x in src[i:i + w]]
            f = src[i][comp]
            filtered = biquad_bandpass(seg, max(80, f), qq)
            for k, x in enumerate(filtered):
                if i + k < n:
                    out[i + k] += x * amp
    for i in range(n):
        out[i] += dry[i] * 0.12 + 0.05 * radio_bed(i, n)
        # биткраш (промежуточный S&H)
        if i % 3:
            out[i] = out[i - 1]
        t = i / n
        out[i] *= 0.6 + 0.4 * min(1.0, min(i, n - i) / (0.2 * n))
    write_wav('mimic', lowpass(out, 3000), 1.5)


def radio_bed(i, n):
    return random.uniform(-1, 1) * 0.5


def sting():
    n = int(2.4 * SR)
    s = silence(2.4)
    for f in (220.0, 233.1, 311.1, 466.2):
        ph = 0.0
        for i in range(n):
            t = i / n
            ph += TWO_PI * f / SR
            a = t ** 2.2 if t < 0.83 else 0.0
            s[i] += math.sin(ph) * a * 0.5
    boom = [math.sin(TWO_PI * 43 * (i / SR)) * (i / n) ** 2 for i in range(n)]
    s = mix([x * 0.7 for x in s], [x * 1.4 for x in boom])
    write_wav('sting', lowpass(s, 1400), 1.35)


def static_burst():
    n = int(0.7 * SR)
    s = noise(0.7)
    cut = 5000
    out = []
    for i in range(n):
        t = i / n
        if i % 60 == 0:
            cut = max(600, 6000 * (1 - t) ** 1.5 + 500)
        lp = lowpass(s[i:i + 1], cut)[0]
        out.append(lp * (math.exp(-2.2 * t) if t > 0.12 else 1.0))
    write_wav('static_burst', out, 1.1)


def door_slam():
    n = int(0.5 * SR)
    nz = lowpass(noise(0.5), 700)
    boom = [math.sin(TWO_PI * 55 * (i / SR)) * math.exp(-16 * i / n) for i in range(n)]
    s = [nz[i] * math.exp(-20 * i / n) * 0.8 + boom[i] * 1.2 for i in range(n)]
    write_wav('door_slam', s, 1.2)


def silence_end():
    n = int(2.5 * SR)
    s = []
    for i in range(n):
        t = i / SR
        v = math.sin(TWO_PI * 523 * t) + 0.8 * math.sin(TWO_PI * 659 * t)
        s.append(v * 0.4 * math.sin(min(1.0, t * 2.5)) * math.exp(-1.2 * max(0.0, t - 1.2)))
    write_wav('silence_end', s, 0.9)


print('generating placeholder sounds -> sounds/*.wav')
hum_room()
hum_transformer()
wind()
radio_loop()
node_hum()
drone_dark()
alarm()
presence()
step('step', 900, 70, 0)
step('step_crouch', 500, 55, 0)
step('step_beast', 300, 44, 0)
clatter()
door_metal()
hatch()
pickup()
fuse_install()
node_on()
drip()
whisper()
mimic()
sting()
static_burst()
door_slam()
silence_end()
print('done')
