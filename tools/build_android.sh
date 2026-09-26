#!/usr/bin/env bash
# Gera os builds Android.
#   tools/build_android.sh debug     -> build/gamehub-debug.apk (instalar no celular pra testar)
#   tools/build_android.sh release   -> build/gamehub.aab (subir na Play Store)
#   tools/build_android.sh apk       -> build/gamehub.apk (release, pra instalar direto no celular)
#   tools/build_android.sh install   -> gera o debug e instala via adb no celular conectado
# A chave de upload fica fora do repositório, em ~/.android-keys (veja docs/ANDROID.md).
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}"
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk-17}"
mkdir -p build
# As bibliotecas do template Gradle não vão pro git (são grandes): recria a partir do template do Godot.
if [ ! -d android/build/libs ]; then
  unzip -q -o "$HOME/.local/share/godot/export_templates/4.7.2.stable/android_source.zip" "libs/*" -d android/build
fi
# Antes de tudo, confere se o pacote exportado abre sem erro de script.
tools/check_export.sh "$G" || exit 1
case "${1:-debug}" in
  debug|install)
    "$G" --headless --export-debug "Android" build/gamehub-debug.apk
    ls -lh build/gamehub-debug.apk
    if [ "${1:-}" = install ]; then adb install -r build/gamehub-debug.apk; fi
    ;;
  release|apk)
    KEYS="$HOME/.android-keys/gamehub-upload.txt"
    [ -f "$KEYS" ] || { echo "Chave de upload não encontrada em $KEYS"; exit 1; }
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(grep '^arquivo=' "$KEYS" | cut -d= -f2-)"
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$(grep '^alias=' "$KEYS" | cut -d= -f2-)"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(grep '^senha=' "$KEYS" | cut -d= -f2-)"
    if [ "$1" = apk ]; then
      "$G" --headless --export-release "Android" build/gamehub.apk
      ls -lh build/gamehub.apk
    else
      "$G" --headless --export-release "Android AAB" build/gamehub.aab
      ls -lh build/gamehub.aab
    fi
    ;;
  *) echo "uso: $0 debug|release|apk|install"; exit 1;;
esac
