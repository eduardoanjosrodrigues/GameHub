#!/usr/bin/env bash
# Exporta pra Linux com os mesmos filtros do Android e roda o pacote exportado por alguns segundos.
# Pega erros que só aparecem no app instalado (ex: script referenciando algo excluído do export).
# Uso: tools/check_export.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
mkdir -p build/linux
"$G" --headless --export-release "Linux (teste do export)" build/linux/gamehub.x86_64 > /dev/null 2>&1
LOG=$(mktemp)
timeout 8 build/linux/gamehub.x86_64 --headless > "$LOG" 2>&1
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" "$LOG"; then
  echo "EXPORT QUEBRADO (log em $LOG)"
  exit 1
fi
echo "EXPORT OK"
