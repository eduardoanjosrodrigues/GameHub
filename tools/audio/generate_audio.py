#!/usr/bin/env python3
"""Gera os efeitos sonoros e as músicas do gamehub por síntese (só biblioteca padrão).

Uso: python3 tools/audio/generate_audio.py
Saída: app/audio/sfx/*.wav, app/audio/music/menu.wav, games/chapeu/audio/*.wav,
games/halli_galli/audio/*.wav

Tudo é sintetizado aqui (ondas simples + envelopes), então não há licença de terceiros.
Pra trocar um som, ajuste a função correspondente e rode de novo.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def note_hz(n):
    """Número MIDI -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "pulse":
        return 1.0 if p < 0.25 else -1.0
    if kind == "tri":
        return 4 * abs(p - 0.5) - 1
    if kind == "saw":
        return 2 * p - 1
    raise ValueError(kind)


def tone(buf, start_s, dur_s, f0, f1=None, kind="sine", vol=0.5, attack=0.005, release=None, vibrato=0.0, wrap=False):
    """Soma um tom (com glissando opcional de f0 a f1) no buffer."""
    f1 = f0 if f1 is None else f1
    release = dur_s * 0.6 if release is None else release
    n = int(dur_s * RATE)
    s0 = int(start_s * RATE)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        k = i / max(n - 1, 1)
        f = f0 + (f1 - f0) * k
        if vibrato:
            f *= 1 + 0.01 * math.sin(2 * math.pi * vibrato * t)
        phase += f / RATE
        if t < attack:
            env = t / attack
        elif t > dur_s - release:
            env = max(0.0, (dur_s - t) / release)
        else:
            env = 1.0
        idx = s0 + i
        if wrap:
            idx %= len(buf)
        elif idx >= len(buf):
            break
        buf[idx] += osc(kind, phase) * env * vol


def noise(buf, start_s, dur_s, vol=0.3, decay=30.0, lowpass=0.0, wrap=False, seed=1):
    rnd = random.Random(seed)
    n = int(dur_s * RATE)
    s0 = int(start_s * RATE)
    last = 0.0
    for i in range(n):
        t = i / RATE
        x = rnd.uniform(-1, 1)
        if lowpass:
            last = last + lowpass * (x - last)
            x = last
        idx = s0 + i
        if wrap:
            idx %= len(buf)
        elif idx >= len(buf):
            break
        buf[idx] += x * vol * math.exp(-decay * t)


def kick(buf, t, wrap=True):
    tone(buf, t, 0.18, 150, 45, "sine", 0.9, 0.001, 0.15, wrap=wrap)


def snare(buf, t, wrap=True):
    noise(buf, t, 0.16, 0.45, 22, 0.6, wrap=wrap, seed=int(t * 1000))
    tone(buf, t, 0.08, 220, 180, "tri", 0.3, 0.001, 0.07, wrap=wrap)


def hat(buf, t, vol=0.18, wrap=True):
    noise(buf, t, 0.05, vol, 80, 0.95, wrap=wrap, seed=int(t * 977))


def save(path, buf, peak=0.9):
    m = max(1e-9, max(abs(x) for x in buf))
    k = peak / m
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with wave.open(full, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * k)) * 32767)) for x in buf))
    print("ok", path, f"{len(buf) / RATE:.2f}s")


def buf_of(seconds):
    return [0.0] * int(seconds * RATE)


# --- Efeitos ---------------------------------------------------------------

def sfx_tap():
    b = buf_of(0.08)
    tone(b, 0, 0.06, 900, 600, "sine", 0.7, 0.001, 0.05)
    return b


def sfx_hit():
    b = buf_of(0.42)
    for i, n in enumerate([72, 76, 79, 84]):
        tone(b, i * 0.06, 0.2, note_hz(n), kind="square", vol=0.25, release=0.15)
        tone(b, i * 0.06, 0.2, note_hz(n), kind="sine", vol=0.3, release=0.15)
    return b


def sfx_skip():
    b = buf_of(0.36)
    tone(b, 0, 0.32, 520, 170, "tri", 0.7, 0.002, 0.2, vibrato=18)
    return b


def sfx_tick():
    b = buf_of(0.06)
    tone(b, 0, 0.04, 1600, 1400, "sine", 0.6, 0.0005, 0.035)
    noise(b, 0, 0.02, 0.15, 150, 0.9)
    return b


def sfx_buzzer():
    b = buf_of(0.8)
    tone(b, 0, 0.75, 170, 160, "saw", 0.35, 0.005, 0.1)
    tone(b, 0, 0.75, 173, 163, "square", 0.25, 0.005, 0.1)
    return b


def sfx_hat_empty():
    b = buf_of(0.9)
    for i, n in enumerate([67, 72, 76, 79, 84, 88]):
        tone(b, i * 0.07, 0.35, note_hz(n), kind="pulse", vol=0.2, release=0.25)
        tone(b, i * 0.07, 0.35, note_hz(n), kind="sine", vol=0.25, release=0.25)
    return b


def sfx_start():
    b = buf_of(0.5)
    tone(b, 0.0, 0.15, note_hz(79), kind="square", vol=0.3, release=0.08)
    tone(b, 0.18, 0.28, note_hz(84), kind="square", vol=0.3, release=0.2)
    return b


def sfx_round():
    b = buf_of(1.0)
    for i, (n, d) in enumerate([(72, 0.14), (72, 0.14), (79, 0.6)]):
        t = [0, 0.16, 0.32][i]
        for off in (0, 4, 7):
            tone(b, t, d, note_hz(n + off), kind="square", vol=0.12, release=d * 0.7)
    return b


def sfx_win():
    b = buf_of(2.2)
    seq = [(72, 0.0, 0.18), (76, 0.18, 0.18), (79, 0.36, 0.18), (84, 0.54, 0.5), (79, 1.04, 0.16), (84, 1.2, 0.9)]
    for n, t, d in seq:
        tone(b, t, d, note_hz(n), kind="square", vol=0.18, release=d * 0.6)
        tone(b, t, d, note_hz(n - 12), kind="tri", vol=0.25, release=d * 0.6)
    for off in (0, 4, 7, 12):
        tone(b, 1.2, 0.95, note_hz(60 + off), kind="sine", vol=0.12, release=0.6)
    return b


def sfx_join():
    b = buf_of(0.25)
    tone(b, 0, 0.1, note_hz(76), kind="sine", vol=0.5, release=0.06)
    tone(b, 0.08, 0.14, note_hz(83), kind="sine", vol=0.5, release=0.1)
    return b


def sfx_leave():
    b = buf_of(0.25)
    tone(b, 0, 0.1, note_hz(79), kind="sine", vol=0.5, release=0.06)
    tone(b, 0.08, 0.14, note_hz(72), kind="sine", vol=0.5, release=0.1)
    return b


def sfx_pop():
    b = buf_of(0.12)
    tone(b, 0, 0.1, 300, 900, "sine", 0.7, 0.001, 0.07)
    return b


# --- Halli Galli -----------------------------------------------------------

def struck(buf, start_s, dur_s, f, partials, vol=0.5, decay=4.0):
    """Sino batido: parciais inarmônicas com decaimento exponencial (as agudas morrem antes)."""
    n = int(dur_s * RATE)
    s0 = int(start_s * RATE)
    for i in range(n):
        t = i / RATE
        x = 0.0
        for mult, amp in partials:
            x += amp * math.sin(2 * math.pi * f * mult * t) * math.exp(-decay * mult ** 0.7 * t)
        idx = s0 + i
        if idx >= len(buf):
            break
        buf[idx] += x * vol * min(1.0, t / 0.0015)


def sfx_hg_bell():
    b = buf_of(1.6)
    struck(b, 0, 1.6, 1480, [(1.0, 1.0), (2.01, 0.5), (2.76, 0.45), (4.07, 0.25), (5.4, 0.2), (8.93, 0.08)], 0.5, 2.6)
    noise(b, 0, 0.012, 0.35, 400, 0.8, seed=3)
    return b


def sfx_hg_flip():
    b = buf_of(0.16)
    noise(b, 0, 0.14, 0.6, 26, 0.35, seed=5)
    tone(b, 0.0, 0.1, 520, 300, "sine", 0.15, 0.002, 0.08)
    return b


def sfx_hg_collect():
    b = buf_of(0.7)
    for i in range(6):
        noise(b, i * 0.045, 0.07, 0.35, 45, 0.4, seed=10 + i)
    for i, n in enumerate([72, 76, 79, 84]):
        tone(b, 0.25 + i * 0.07, 0.22, note_hz(n), kind="square", vol=0.16, release=0.16)
        tone(b, 0.25 + i * 0.07, 0.22, note_hz(n), kind="sine", vol=0.25, release=0.16)
    return b


def sfx_hg_wrong():
    b = buf_of(0.6)
    tone(b, 0, 0.22, 196, 185, "saw", 0.35, 0.004, 0.06)
    tone(b, 0, 0.22, 199, 188, "square", 0.2, 0.004, 0.06)
    tone(b, 0.28, 0.3, 175, 150, "saw", 0.35, 0.004, 0.12)
    tone(b, 0.28, 0.3, 178, 153, "square", 0.2, 0.004, 0.12)
    return b


def sfx_hg_turn():
    b = buf_of(0.3)
    tone(b, 0, 0.1, note_hz(84), kind="sine", vol=0.45, release=0.07)
    tone(b, 0.11, 0.16, note_hz(88), kind="sine", vol=0.45, release=0.12)
    return b


def sfx_hg_out():
    b = buf_of(0.8)
    for i, n in enumerate([72, 69, 65, 60]):
        tone(b, i * 0.14, 0.2, note_hz(n), kind="tri", vol=0.4, release=0.14)
    return b


# --- Músicas ---------------------------------------------------------------

def music_menu():
    bpm = 116
    beat = 60 / bpm
    bars = 8
    b = buf_of(bars * 4 * beat)
    # Progressão C - Am - F - G (duas vezes)
    chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]] * 2
    bass = [36, 33, 29, 31] * 2
    melody = [
        [(76, 0, 1), (79, 1, 0.5), (76, 1.5, 0.5), (74, 2, 1), (72, 3, 1)],
        [(72, 0, 0.5), (74, 0.5, 0.5), (76, 1, 1), (72, 2, 2)],
        [(69, 0, 1), (72, 1, 0.5), (74, 1.5, 0.5), (76, 2, 1.5), (74, 3.5, 0.5)],
        [(74, 0, 1), (71, 1, 1), (67, 2, 2)],
        [(76, 0, 0.5), (76, 0.5, 0.5), (79, 1, 1), (81, 2, 1), (79, 3, 1)],
        [(76, 0, 1), (74, 1, 1), (72, 2, 2)],
        [(77, 0, 1), (76, 1, 1), (74, 2, 1), (72, 3, 1)],
        [(74, 0, 1.5), (71, 1.5, 0.5), (72, 2, 2)],
    ]
    for bar in range(bars):
        t0 = bar * 4 * beat
        for k in range(4):
            tone(b, t0 + k * beat, beat * 0.9, note_hz(bass[bar]), kind="tri", vol=0.35, release=beat * 0.4, wrap=True)
        for k in (0.5, 1.5, 2.5, 3.5):
            for n in chords[bar]:
                tone(b, t0 + k * beat, beat * 0.35, note_hz(n), kind="pulse", vol=0.05, release=beat * 0.2, wrap=True)
        for n, st, d in melody[bar]:
            tone(b, t0 + st * beat, d * beat * 0.95, note_hz(n), kind="square", vol=0.1, release=d * beat * 0.4, vibrato=5, wrap=True)
            tone(b, t0 + st * beat, d * beat * 0.95, note_hz(n), kind="sine", vol=0.12, release=d * beat * 0.4, wrap=True)
        kick(b, t0)
        kick(b, t0 + 2 * beat)
        snare(b, t0 + beat)
        snare(b, t0 + 3 * beat)
        for k in range(8):
            hat(b, t0 + k * beat / 2, 0.1 if k % 2 else 0.16)
    return b


def music_turn():
    bpm = 138
    beat = 60 / bpm
    bars = 8
    b = buf_of(bars * 4 * beat)
    # Am - Am - F - E: tensão de relógio correndo
    roots = [45, 45, 41, 40] * 2
    arps = [[69, 72, 76, 72], [69, 72, 76, 79], [65, 69, 72, 69], [64, 68, 71, 68]] * 2
    for bar in range(bars):
        t0 = bar * 4 * beat
        for k in range(8):
            tone(b, t0 + k * beat / 2, beat * 0.45, note_hz(roots[bar]), kind="saw", vol=0.16, release=beat * 0.2, wrap=True)
        for k in range(16):
            n = arps[bar][k % 4] + (12 if k >= 12 and bar % 2 else 0)
            tone(b, t0 + k * beat / 4, beat * 0.22, note_hz(n), kind="pulse", vol=0.06, release=beat * 0.12, wrap=True)
        for k in range(4):
            kick(b, t0 + k * beat)
        snare(b, t0 + beat)
        snare(b, t0 + 3 * beat)
        for k in range(16):
            hat(b, t0 + k * beat / 4, 0.12 if k % 2 else 0.07)
        # "tique-taque" de relógio
        for k in range(4):
            tone(b, t0 + k * beat + beat / 2, 0.03, 2000 if k % 2 else 1500, kind="sine", vol=0.15, release=0.025, wrap=True)
    return b


def main():
    sfx = {
        "tap": sfx_tap, "hit": sfx_hit, "skip": sfx_skip, "tick": sfx_tick, "buzzer": sfx_buzzer,
        "hat_empty": sfx_hat_empty, "start": sfx_start, "round": sfx_round, "win": sfx_win,
        "join": sfx_join, "leave": sfx_leave, "pop": sfx_pop,
    }
    for name, fn in sfx.items():
        folder = "app/audio/sfx" if name in ("tap", "join", "leave", "pop") else "games/chapeu/audio"
        save(f"{folder}/{name}.wav", fn(), 0.8)
    halli = {
        "hg_bell": sfx_hg_bell, "hg_flip": sfx_hg_flip, "hg_collect": sfx_hg_collect,
        "hg_wrong": sfx_hg_wrong, "hg_turn": sfx_hg_turn, "hg_out": sfx_hg_out,
    }
    for name, fn in halli.items():
        save(f"games/halli_galli/audio/{name}.wav", fn(), 0.8)
    save("app/audio/music/menu.wav", music_menu(), 0.7)
    save("games/chapeu/audio/turn.wav", music_turn(), 0.7)


if __name__ == "__main__":
    main()
