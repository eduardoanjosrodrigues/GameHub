#!/usr/bin/env python3
"""Gera docs/privacidade/index.html a partir de docs/politica-de-privacidade.md.

A página é publicada pelo GitHub Pages (Settings > Pages > main, pasta /docs) em
https://eduardoanjosrodrigues.github.io/GameHub/privacidade/ — é o link da Play Store e do app.
Rode depois de mudar a política e faça commit dos dois arquivos.
"""
import pathlib

import markdown

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "politica-de-privacidade.md"
OUT = ROOT / "docs" / "privacidade" / "index.html"

PAGE = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Política de Privacidade · GameHub</title>
<style>
  :root {{ --papel: #F5EFE3; --tinta: #2B2622; --suave: #6B6358; --linha: #E2D8C6; --azul: #2B59C3; }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --papel: #1E1B18; --tinta: #F2ECE2; --suave: #B5AB9C; --linha: #3A342D; --azul: #8FB0FF; }}
  }}
  body {{ margin: 0; background: var(--papel); color: var(--tinta);
    font: 17px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
  main {{ max-width: 720px; margin: 0 auto; padding: 40px 20px 64px; }}
  h1 {{ font-size: 30px; line-height: 1.2; margin: 0 0 8px; }}
  h1 + p {{ color: var(--suave); margin-top: 0; }}
  h2 {{ font-size: 21px; margin: 36px 0 8px; padding-top: 20px; border-top: 1px solid var(--linha); }}
  ul {{ padding-left: 22px; }}
  li {{ margin: 4px 0; }}
  a {{ color: var(--azul); }}
</style>
</head>
<body>
<main>
{body}
</main>
</body>
</html>
"""

body = markdown.markdown(SRC.read_text(encoding="utf-8"), output_format="html")
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(PAGE.format(body=body), encoding="utf-8")
print(f"ok: {OUT.relative_to(ROOT)}")
