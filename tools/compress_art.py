#!/usr/bin/env python3
"""Comprime a arte do Nano Banana pra ir no APK e na página do navegador (Avalon e Secret Hitler).

Cada JPG/PNG das pastas de arte vira WebP qualidade 80, no mesmo tamanho (sem diferença visível,
cerca de 1/10 do tamanho). O original vai pra art_originais/, que fica no repositório mas não
entra no APK (tem .gdignore e está no exclude_filter do export).
Uso: python3 tools/compress_art.py (o tools/sync_web_assets.sh já chama).
"""
import os
import subprocess

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["games/avalon/art/roles", "games/avalon/art", "games/secret_hitler/art/roles", "games/secret_hitler/art"]
KEEP = os.path.join(ROOT, "art_originais")
QUALITY = 80


def tracked(path):
    r = subprocess.run(["git", "ls-files", "--error-unmatch", path], cwd=ROOT, capture_output=True)
    return r.returncode == 0


saved = 0
for d in DIRS:
    full = os.path.join(ROOT, d)
    if not os.path.isdir(full):
        continue
    for name in sorted(os.listdir(full)):
        base, ext = os.path.splitext(name)
        if ext.lower() not in (".png", ".jpg", ".jpeg"):
            continue
        src = os.path.join(full, name)
        dst = os.path.join(full, base + ".webp")
        Image.open(src).save(dst, "WEBP", quality=QUALITY, method=6)
        before, after = os.path.getsize(src), os.path.getsize(dst)
        saved += before - after
        # Guarda o original fora do jogo, na mesma estrutura de pastas.
        keep = os.path.join(KEEP, os.path.relpath(src, os.path.join(ROOT, "games")))
        os.makedirs(os.path.dirname(keep), exist_ok=True)
        if tracked(src):
            subprocess.run(["git", "mv", "-f", src, keep], cwd=ROOT, check=True)
        else:
            os.replace(src, keep)
        if os.path.exists(src + ".import"):
            if tracked(src + ".import"):
                subprocess.run(["git", "rm", "-q", "-f", src + ".import"], cwd=ROOT, check=True)
            else:
                os.remove(src + ".import")
        print(f"{d}/{name}: {before // 1024} KB -> {base}.webp {after // 1024} KB")
if saved:
    print(f"economia: {saved / 1048576:.1f} MB")
