#!/usr/bin/env python3
"""Sons do Quem Foi? (docs/PLANO_QUEM_FOI.md §4.3), com as mesmas ferramentas de síntese do
generate_audio.py. Uso: python3 tools/audio/generate_quem_foi_audio.py
Saída: games/quem_foi/audio/qf_pum.wav, qf_plim.wav, qf_descarga.wav
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_audio import RATE, buf_of, noise, save, tone  # noqa: E402


def qf_pum():
    """Pum de desenho animado: um ronco grave que treme e desce, com um sopro."""
    b = buf_of(0.55)
    rnd = random.Random(7)
    n = len(b)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        k = i / n
        # Frequência grave, descendo, com tremido irregular (a "borracha").
        f = 95 - 40 * k + 18 * math.sin(2 * math.pi * 23 * t) + rnd.uniform(-6, 6)
        phase += f / RATE
        p = phase % 1.0
        x = (2 * p - 1) * 0.6 + (1.0 if p < 0.3 else -1.0) * 0.4
        env = min(1.0, t / 0.02) * (1 - k) ** 1.4
        b[i] += x * env * 0.7
    noise(b, 0.0, 0.5, 0.12, 6, 0.25, seed=3)
    save("games/quem_foi/audio/qf_pum.wav", b, 0.8)


def qf_plim():
    """Plim: ganhou a corrida."""
    b = buf_of(0.45)
    tone(b, 0.0, 0.18, 1318, None, "sine", 0.5, 0.002, 0.16)
    tone(b, 0.07, 0.35, 1976, None, "sine", 0.45, 0.002, 0.33)
    tone(b, 0.07, 0.35, 3952, None, "sine", 0.08, 0.002, 0.2)
    save("games/quem_foi/audio/qf_plim.wav", b)


def qf_descarga():
    """Descarga de privada: um jato de água que cresce e some, com gorgolejo no fim."""
    b = buf_of(1.9)
    rnd = random.Random(11)
    n = len(b)
    last = 0.0
    for i in range(n):
        t = i / RATE
        k = i / n
        x = rnd.uniform(-1, 1)
        cut = 0.08 + 0.25 * math.sin(math.pi * min(1.0, t / 1.4))
        last += cut * (x - last)
        env = min(1.0, t / 0.35) * (1 - k) ** 0.8
        b[i] += last * env * 0.9
    # Gorgolejo: bolhas que sobem de tom.
    for j in range(9):
        s = 1.0 + j * 0.08 + rnd.uniform(0, 0.03)
        tone(b, s, 0.07, 280 + rnd.uniform(0, 120), 700 + rnd.uniform(0, 200), "sine", 0.18, 0.005, 0.05)
    save("games/quem_foi/audio/qf_descarga.wav", b, 0.8)


if __name__ == "__main__":
    qf_pum()
    qf_plim()
    qf_descarga()
