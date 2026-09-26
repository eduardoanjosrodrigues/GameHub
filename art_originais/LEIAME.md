# Arte original

Os arquivos que vieram do Nano Banana, sem compressão. O app e a página do navegador usam as
cópias em WebP (qualidade 80) que ficam em `games/*/art/`; esta pasta não vai pro APK
(`.gdignore` + `exclude_filter` do export). `tools/compress_art.py` faz a conversão e move os
originais pra cá: basta salvar a arte nova em `games/*/art/` e rodar `tools/sync_web_assets.sh`.
