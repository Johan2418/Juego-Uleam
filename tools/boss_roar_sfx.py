"""Gritos de los bosses (presentación y cambio de fase) + rumor de tensión de la intro.

    assets/audio/bosses/<boss>_roar.ogg   grito: rugido grave con formantes ("AAAAH" → "OOOH"), raspado,
                                          distorsión y una capa propia de cada boss (robot, máquina, persona...)
    assets/audio/bosses/title_slam.ogg    golpe de la tarjeta de presentación (nombre del boss)
    assets/audio/bosses/intro_rumble.ogg  zumbido grave que sube + latidos (mientras el boss se presenta)
Uso: python tools/boss_roar_sfx.py <carpeta_wav>   (después convierte a .ogg en assets/audio/bosses/)
"""
import os
import subprocess
import sys

import numpy as np
from scipy import signal

SR = 32000
rng = np.random.default_rng(3)
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "bosses")


def t_(d):
    return np.arange(int(d * SR)) / SR


def env(n, a, r):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na)
    e[n - nr:] *= np.linspace(1, 0, nr) ** 1.5
    return e


def bandpass(x, f, q):
    b, a = signal.iirpeak(f / (SR / 2), q)
    return signal.lfilter(b, a, x)


def lowpass(x, f):
    b, a = signal.butter(2, f / (SR / 2))
    return signal.lfilter(b, a, x)


def highpass(x, f):
    b, a = signal.butter(2, f / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def growl(d=1.9, f0=(95, 58), vowel=((750, 1150), (420, 800)), rasp=34.0, drive=3.0, robot=0.0, crush=0):
    """Rugido: diente de sierra que baja, raspado (AM), formantes que pasan de A a O, distorsión."""
    t = t_(d)
    n = len(t)
    k = t / d
    f = f0[0] * (1 - k) + f0[1] * k
    f = f * (1 + 0.04 * np.sin(2 * np.pi * 5.5 * t) + 0.02 * rng.standard_normal(n).cumsum() / np.sqrt(n) * 3)
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1.0) - 1
    sub = np.sin(2 * np.pi * ph * 0.5)
    noise = rng.uniform(-1, 1, n)
    src = saw + 0.35 * noise + 0.5 * sub
    src *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * rasp * t))          # raspado
    out = np.zeros(n)
    for (fa, fb), g in zip(zip(vowel[0], vowel[1]), (1.0, 0.6)):
        seg = 2048
        for i in range(0, n, seg):
            kk = i / n
            fc = fa * (1 - kk) + fb * kk
            out[i:i + seg] += bandpass(src[max(0, i - 512):i + seg], fc, 3.0)[-len(src[i:i + seg]):] * g
    out += lowpass(src, 260) * 0.8
    if robot > 0:
        out = out * (1 - robot) + out * np.sin(2 * np.pi * 70 * t) * robot     # modulación en anillo
    if crush:
        steps = 2 ** crush
        out = np.round(out / (np.abs(out).max() + 1e-9) * steps) / steps
    out = np.tanh(out * drive)
    return out * env(n, 0.06, 0.7)


def beep(f, d, vol=0.4, sq=False):
    t = t_(d)
    w = np.sign(np.sin(2 * np.pi * f * t)) if sq else np.sin(2 * np.pi * f * t)
    return w * vol * env(len(t), 0.005, d * 0.5)


def hit(f=60, d=0.5, vol=1.0):
    t = t_(d)
    fr = f * (1 + 2.5 * np.exp(-t * 25))
    return np.tanh(np.sin(2 * np.pi * np.cumsum(fr) / SR) * 2.5) * np.exp(-t * 7) * vol


def metal(d=0.8, vol=0.5):
    t = t_(d)
    x = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((523, 5), (1307, 7), (2150, 9), (3417, 12)))
    return x * 0.25 * vol


def noise_burst(d, f_lo, f_hi, vol=0.5):
    x = rng.uniform(-1, 1, int(d * SR))
    x = highpass(lowpass(x, f_hi), f_lo)
    return x * vol * env(len(x), 0.01, d * 0.6) / (np.abs(x).max() + 1e-9)


def screech(d=0.9, vol=0.35):
    """Chirrido de tiza en la pizarra."""
    t = t_(d)
    f = 2400 + 600 * np.sin(2 * np.pi * 9 * t) + rng.uniform(-200, 200, len(t))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 23 * t)))
    return x * vol * env(len(t), 0.02, 0.3)


def mix(*parts):
    n = max(len(p[1]) + int(p[0] * SR) for p in parts)
    out = np.zeros(n)
    for at, x, *g in parts:
        s = int(at * SR)
        out[s:s + len(x)] += x * (g[0] if g else 1.0)
    return out


def reverb(x, dec=0.35, mix_=0.3):
    out = x.copy()
    for d, g in ((0.043, 0.6), (0.071, 0.5), (0.113, 0.4), (0.167, 0.3), (0.251, 0.22)):
        s = int(d * SR)
        out[s:] += x[:-s] * g * dec * 2
    return x * (1 - mix_) + out * mix_


def roar(kind):
    if kind == "deadbeef":      # bestia de chatarra: rugido grave + bytes que pitan + metal
        g = growl(2.1, (85, 52), robot=0.25, drive=3.5)
        bytes_ = np.concatenate([beep(rng.choice([880, 1320, 1760, 2200]), 0.05, 0.25, True) for _ in range(16)])
        return mix((0, g), (0.1, metal(1.0, 0.7)), (0.9, bytes_, 0.6))
    if kind == "bsod":          # cirujano: pitido del monitor + descarga + rugido eléctrico
        g = growl(1.7, (110, 70), robot=0.5, crush=5, drive=3)
        zap = noise_burst(0.35, 1500, 9000, 0.7) * np.sign(np.sin(2 * np.pi * 60 * t_(0.35)))
        return mix((0, beep(1000, 0.18, 0.4)), (0.25, beep(1000, 0.18, 0.4)), (0.5, zap), (0.55, g))
    if kind == "div0":          # bóveda: campana del mercado + monedas + rugido metálico
        g = growl(1.8, (95, 60), robot=0.35, drive=3)
        bell = sum(np.sin(2 * np.pi * f * t_(1.4)) * np.exp(-t_(1.4) * k) for f, k in ((660, 2), (990, 3), (1320, 4))) * 0.2
        coins = np.concatenate([beep(rng.uniform(3000, 5000), 0.03, 0.2) for _ in range(20)])
        return mix((0, bell), (0.2, g), (0.8, coins, 0.7))
    if kind == "syntax":        # profesor: chirrido de tiza + grito "¡SILENCIO!" grave
        g = growl(1.6, (120, 80), vowel=((500, 1500), (650, 1100)), robot=0.3, drive=2.6)
        return mix((0, screech(0.8)), (0.5, g), (0.5, hit(55, 0.5, 0.6)))
    if kind == "stack":         # máquina de obra: motor que acelera + bocina + rugido
        t = t_(1.6)
        rev = np.sign(np.sin(2 * np.pi * np.cumsum(40 + 80 * (t / 1.6) ** 2) / SR)) * 0.3
        rev = lowpass(rev, 900) * env(len(t), 0.1, 0.4)
        horn = (np.sign(np.sin(2 * np.pi * 311 * t_(0.6))) + np.sign(np.sin(2 * np.pi * 370 * t_(0.6)))) * 0.12
        g = growl(1.7, (80, 50), robot=0.3, drive=3.5)
        return mix((0, rev), (0.9, horn), (1.0, g))
    if kind == "judge":         # juez: tres mazazos + "¡ORDEN!" grave con eco
        g = growl(1.8, (75, 48), vowel=((450, 900), (380, 700)), robot=0.2, drive=2.8)
        return mix((0, hit(70, 0.5)), (0.35, hit(70, 0.5)), (0.7, hit(65, 0.7, 1.2)), (0.8, reverb(g, 0.5, 0.45)))
    if kind == "tex":           # estatua: piedra que cruje + glitch + lamento grave
        crack = noise_burst(0.8, 80, 1200, 0.6)
        g = growl(2.0, (70, 45), vowel=((380, 700), (300, 600)), drive=2.4, crush=4)
        st = g.copy()
        seg = int(0.04 * SR)
        for i in range(int(0.4 * SR), int(0.9 * SR), seg * 2):     # tartamudeo de glitch
            st[i + seg:i + 2 * seg] = st[i:i + seg]
        return mix((0, crack), (0.4, reverb(st, 0.5, 0.4)))
    if kind == "kp":            # chef: campanita del microondas + acople + grito
        ding = sum(np.sin(2 * np.pi * f * t_(0.9)) * np.exp(-t_(0.9) * 5) for f in (2093, 2637)) * 0.25
        fb = np.sin(2 * np.pi * 3200 * t_(0.7)) * env(int(0.7 * SR), 0.3, 0.2) * 0.15
        g = growl(1.7, (130, 85), vowel=((700, 1200), (500, 900)), robot=0.4, drive=3)
        return mix((0, ding), (0.35, fb), (0.6, g))
    if kind == "sudo":          # persona: grito humano "¡VAMOS!" con eco de auditorio + subida de sinte
        g = growl(1.3, (190, 150), vowel=((800, 1250), (600, 1000)), rasp=0.0, drive=1.6)
        t = t_(1.2)
        rise = np.sin(2 * np.pi * np.cumsum(200 + 800 * (t / 1.2) ** 2) / SR) * 0.12 * (t / 1.2)
        return mix((0, rise), (1.0, reverb(g, 0.6, 0.5)), (1.0, hit(50, 0.6, 0.7)))
    raise ValueError(kind)


def rumble(d=6.0):
    """Tensión de la intro: zumbido grave que sube, latidos y viento (se reproduce en bucle)."""
    t = t_(d)
    k = t / d
    drone = sum(np.sin(2 * np.pi * f * t + i) for i, f in enumerate((41.2, 41.7, 61.7, 82.4))) * 0.18
    drone *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * t) ** 2
    wind = lowpass(rng.uniform(-1, 1, len(t)), 500) * 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.17 * t))
    beat = np.zeros(len(t))
    for s in np.arange(0.0, d, 1.0):
        for off, v in ((0.0, 1.0), (0.22, 0.6)):
            h = hit(48, 0.35, 0.5 * v)
            i = int((s + off) * SR)
            beat[i:i + len(h)] += h[:len(beat) - i]
    x = drone + wind + beat
    # bucle sin corte: fundido cruzado del final con el principio
    f = int(0.5 * SR)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    return x[:-f]


def slam():
    """Golpe de la tarjeta de presentación: whoosh que sube + golpe grave + platillo metálico."""
    t = t_(0.45)
    whoosh = highpass(rng.uniform(-1, 1, len(t)), 600) * (t / 0.45) ** 2 * 0.5
    return mix((0, whoosh), (0.42, hit(45, 1.2, 1.3)), (0.42, metal(1.4, 0.8)), (0.42, noise_burst(1.0, 2000, 12000, 0.35)))


def save(path, x, peak=0.9):
    x = x / (np.abs(x).max() + 1e-9) * peak
    import wave
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32000).astype(np.int16).tobytes())


if __name__ == "__main__":
    tmp = sys.argv[1]
    os.makedirs(tmp, exist_ok=True)
    for kind in ["deadbeef", "bsod", "div0", "syntax", "stack", "judge", "tex", "kp", "sudo"]:
        w = os.path.join(tmp, f"{kind}_roar.wav")
        save(w, roar(kind))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT_DIR, f"{kind}_roar.ogg")], check=True)
        print(kind)
    w = os.path.join(tmp, "title_slam.wav")
    save(w, slam())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT_DIR, "title_slam.ogg")], check=True)
    w = os.path.join(tmp, "intro_rumble.wav")
    save(w, rumble(), 0.6)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT_DIR, "intro_rumble.ogg")], check=True)
    print("intro_rumble")
