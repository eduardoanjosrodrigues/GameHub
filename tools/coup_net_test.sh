#!/usr/bin/env bash
# Teste de rede do Coup: 1 host + 3 robôs (redes diferentes) + 1 tabuleiro jogam uma partida inteira,
# com o Embaixador e depois com o Inquisidor. Os robôs blefam, desafiam e bloqueiam ao acaso e
# conferem que ninguém recebe carta escondida alheia. Caio derruba a conexão no meio e volta.
# Uso: tools/coup_net_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
FAIL=0
for FIFTH in embaixador inquisidor; do
  OUT=$(mktemp -d)
  timeout 280 $G --headless -- --cbot=host --bot-name=Host --bot-players=4 --bot-fifth=$FIFTH > "$OUT/host.log" 2>&1 &
  sleep 2
  timeout 280 $G --headless -- --cbot=client --bot-name=Bia --bot-lag=150 > "$OUT/Bia.log" 2>&1 &
  timeout 280 $G --headless -- --cbot=client --bot-name=Caio --bot-lag=40 --bot-drop > "$OUT/Caio.log" 2>&1 &
  timeout 280 $G --headless -- --cbot=client --bot-name=Duda > "$OUT/Duda.log" 2>&1 &
  timeout 280 $G --headless -- --cbot=client --bot-name=Mesa --bot-board > "$OUT/Mesa.log" 2>&1 &
  wait
  echo "== $FIFTH =="
  grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando" | sort | uniq
  for n in host Bia Caio Duda Mesa; do
    grep -q "BOT .*: FIM" "$OUT/$n.log" || { echo "FALHA: $n não terminou ($FIFTH)"; FAIL=1; }
  done
  grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
  grep -q "\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
  [ $FAIL -eq 0 ] || echo "logs em $OUT"
done
[ $FAIL -eq 0 ] && echo "COUP REDE OK"
exit $FAIL
