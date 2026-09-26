#!/usr/bin/env bash
# Teste de justiça do sino no Halli Galli: 1 host + 3 robôs em localhost, cada um com um atraso
# de rede artificial. Quem toca primeiro (Bia) tem a PIOR rede e mesmo assim tem que ganhar todas.
# Caio derruba a própria conexão no meio: a partida pausa e volta.
# Uso: tools/halli_net_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
$G --headless -- --hbot=host --bot-name=Host --bot-players=4 --bot-earliest=Bia > "$OUT/host.log" 2>&1 &
sleep 2
$G --headless -- --hbot=client --bot-name=Bia --bot-lag=200 --bot-offset=0 > "$OUT/bia.log" 2>&1 &
$G --headless -- --hbot=client --bot-name=Caio --bot-lag=80 --bot-offset=40 --bot-drop > "$OUT/caio.log" 2>&1 &
$G --headless -- --hbot=client --bot-name=Duda --bot-lag=0 --bot-offset=80 > "$OUT/duda.log" 2>&1 &
wait -n 2>/dev/null
sleep 1
pkill -f -- "--hbot=client" 2>/dev/null
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "JUSTO|FIM|ERRO|ENCERRADO|TIMEOUT|derrubando|paused|resumed" | sort | uniq
FAIL=0
grep -q "FIM justos=6/6" "$OUT/host.log" || { echo "FALHA: nem todo sino foi justo"; FAIL=1; }
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
grep -q "\"type\":\"paused\"" "$OUT/host.log" || { echo "FALHA: host não pausou na queda"; FAIL=1; }
grep -q "\"type\":\"resumed\"" "$OUT/host.log" || { echo "FALHA: partida não voltou"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "HALLI REDE OK" || echo "logs em $OUT"
exit $FAIL
