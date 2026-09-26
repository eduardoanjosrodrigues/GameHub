#!/usr/bin/env bash
# Teste de rede da Sintonia ou do Ito: 1 host + 4 jogadores robôs + 1 tabuleiro jogam uma partida
# inteira. Um jogador derruba a própria conexão no meio; o jogo segue e ele volta.
# Uso: tools/party_net_test.sh ito|sintonia [caminho do godot]
set -u
GAME="${1:-ito}"
G="${2:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
timeout 200 $G --headless -- --pbot=host --bot-game=$GAME --bot-name=Host --bot-players=5 > "$OUT/host.log" 2>&1 &
sleep 2
for n in Bia Caio Duda; do
  timeout 200 $G --headless -- --pbot=client --bot-game=$GAME --bot-name=$n > "$OUT/$n.log" 2>&1 &
done
timeout 200 $G --headless -- --pbot=client --bot-game=$GAME --bot-name=Gil --bot-drop > "$OUT/Gil.log" 2>&1 &
timeout 200 $G --headless -- --pbot=client --bot-game=$GAME --bot-name=Mesa --bot-board > "$OUT/Mesa.log" 2>&1 &
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando" | sort | uniq
FAIL=0
for n in host Bia Caio Duda Gil Mesa; do
  grep -q "BOT .*: FIM" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
grep -q "\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "$(echo $GAME | tr a-z A-Z) REDE OK" || echo "logs em $OUT"
exit $FAIL
