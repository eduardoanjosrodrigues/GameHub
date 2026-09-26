#!/usr/bin/env bash
# Teste de rede do Secret Hitler: 1 host + 6 jogadores robôs + 1 tabuleiro jogam partidas inteiras.
# Um jogador derruba a própria conexão no meio; o jogo espera e ele volta.
# Uso: tools/sh_net_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
$G --headless -- --sbot=host --bot-name=Host --bot-players=7 > "$OUT/host.log" 2>&1 &
sleep 2
for n in Bia Caio Duda Eva Fabi; do
  $G --headless -- --sbot=client --bot-name=$n > "$OUT/$n.log" 2>&1 &
done
$G --headless -- --sbot=client --bot-name=Gil --bot-drop > "$OUT/Gil.log" 2>&1 &
$G --headless -- --sbot=client --bot-name=Mesa --bot-board > "$OUT/Mesa.log" 2>&1 &
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando" | sort | uniq
FAIL=0
for n in host Bia Caio Duda Eva Fabi Gil Mesa; do
  grep -q "FIM vencedor" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
grep -q "\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "SECRET HITLER REDE OK" || echo "logs em $OUT"
exit $FAIL
