#!/usr/bin/env bash
# Copia pra web/assets/ as fontes, artes e sons que a página do navegador usa.
# O Godot converte SVG/WAV/TTF ao importar e não exporta o arquivo original; aqui cada cópia ganha
# um .import "keep", que faz o arquivo ir pro app exatamente como está (o WebGateway serve ele).
# Rode de novo depois de mudar alguma arte ou som. Uso: tools/sync_web_assets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=web/assets
rm -rf "$OUT"
mkdir -p "$OUT"
cp design/fonts/Fraunces.ttf design/fonts/Manrope.ttf "$OUT/"
cp games/halli_galli/art/{banana,morango,limao,ameixa,sino}.svg "$OUT/"
cp design/icons/{halli_galli,chapeu,rodada_descrever,rodada_uma_palavra,rodada_mimica}.svg "$OUT/"
for i in back check skip pause play trophy people close enter phone; do
  cp "design/icons/$i.svg" "$OUT/icon_$i.svg"
done
cp games/halli_galli/audio/hg_{bell,flip,collect,wrong,turn,out}.wav "$OUT/"
cp games/chapeu/audio/{win,hit,skip,tick,buzzer,start,round}.wav "$OUT/"
cp app/audio/sfx/{join,pop,tap}.wav "$OUT/"
cp design/icons/avalon.svg "$OUT/"
cp games/avalon/art/*.svg "$OUT/"
for f in games/avalon/art/emblems/*.svg; do cp "$f" "$OUT/emblema_$(basename "$f")"; done
cp design/icons/secret_hitler.svg "$OUT/"
for f in games/secret_hitler/art/*.svg; do cp "$f" "$OUT/sh_$(basename "$f")"; done
for f in games/secret_hitler/art/emblems/*.svg; do cp "$f" "$OUT/sh_emblema_$(basename "$f")"; done
# Arte do Nano Banana (docs/avalon_prompts.md, docs/secret_hitler_prompts.md), se já tiver sido gerada. Antes, arruma extensões
# erradas (JPEG salvo como .png). As imagens não são copiadas: ficam em games/avalon/art/ com
# importer "keep" (o app lê o arquivo cru e o WebGateway serve o mesmo em /assets/avalon/ e /assets/sh/), pra não
# ir duas vezes no APK.
python3 tools/fix_avalon_art.py
for f in games/avalon/art/roles/*.{png,jpg,webp} games/avalon/art/*.{png,jpg,webp} games/secret_hitler/art/roles/*.{png,jpg,webp} games/secret_hitler/art/*.{png,jpg,webp}; do
  [ -f "$f" ] && printf '[remap]\n\nimporter="keep"\n' > "$f.import"
done
for f in $(find "$OUT" -type f ! -name '*.import'); do
  printf '[remap]\n\nimporter="keep"\n' > "$f.import"
done
echo "$(find "$OUT" -type f ! -name '*.import' | wc -l) arquivos em $OUT"
