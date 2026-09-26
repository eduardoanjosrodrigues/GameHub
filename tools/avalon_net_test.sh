#!/usr/bin/env bash
# Teste de rede do Avalon: 1 host + 4 jogadores robôs + 1 tabuleiro jogam uma partida inteira.
# Um jogador derruba a própria conexão no meio; o jogo espera e ele volta.
# Uso: tools/avalon_net_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
$G --headless -- --abot=host --bot-name=Host --bot-players=5 > "$OUT/host.log" 2>&1 &
sleep 2
for n in Bia Caio Duda; do
  $G --headless -- --abot=client --bot-name=$n > "$OUT/$n.log" 2>&1 &
done
$G --headless -- --abot=client --bot-name=Eva --bot-drop > "$OUT/Eva.log" 2>&1 &
$G --headless -- --abot=client --bot-name=Mesa --bot-board > "$OUT/Mesa.log" 2>&1 &
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando|connected" | sort | uniq
FAIL=0
for n in host Bia Caio Duda Eva Mesa; do
  grep -q "FIM vencedor" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
grep -q "\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "AVALON REDE OK" || echo "logs em $OUT"
exit $FAIL
