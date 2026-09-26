#!/usr/bin/env python3
"""Arruma a extensão das artes geradas no Nano Banana (Avalon e Secret Hitler).

O gerador às vezes salva JPEG com nome .png; o Godot escolhe o importador pela extensão e não
consegue abrir. Aqui cada arquivo ganha a extensão do formato de verdade (os bytes não mudam).
Uso: python3 tools/fix_avalon_art.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["games/avalon/art/roles", "games/avalon/art", "games/secret_hitler/art/roles", "games/secret_hitler/art", "games/quem_foi/art"]


def real_ext(path):
    with open(path, "rb") as f:
        head = f.read(12)
    if head.startswith(b"\x89PNG"):
        return ".png"
    if head.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return ".webp"
    return None


for d in DIRS:
    full = os.path.join(ROOT, d)
    if not os.path.isdir(full):
        continue
    for name in sorted(os.listdir(full)):
        base, ext = os.path.splitext(name)
        if ext.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        path = os.path.join(full, name)
        want = real_ext(path)
        if want is None or ext.lower() == want or (want == ".jpg" and ext.lower() == ".jpeg"):
            continue
        new = os.path.join(full, base + want)
        os.replace(path, new)
        for stale in (path + ".import",):
            if os.path.exists(stale):
                os.remove(stale)
        print(f"{d}/{name} -> {base}{want}")
