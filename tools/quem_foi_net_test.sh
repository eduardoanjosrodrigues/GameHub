#!/usr/bin/env bash
# Teste de rede do Quem Foi?: 1 host + 3 robôs com atrasos de rede diferentes + 1 tabuleiro jogam uma
# partida inteira. Em cada corrida, quem toca primeiro (Bia) tem a PIOR rede e mesmo assim tem que
# ganhar. Caio derruba a própria conexão no meio e volta.
# Uso: tools/quem_foi_net_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
timeout 200 $G --headless -- --qbot=host --bot-name=Host --bot-players=4 --bot-order=Bia,Caio,Duda > "$OUT/host.log" 2>&1 &
sleep 2
timeout 200 $G --headless -- --qbot=client --bot-name=Bia --bot-lag=200 --bot-offset=0 > "$OUT/Bia.log" 2>&1 &
timeout 200 $G --headless -- --qbot=client --bot-name=Caio --bot-lag=80 --bot-offset=60 --bot-drop > "$OUT/Caio.log" 2>&1 &
timeout 200 $G --headless -- --qbot=client --bot-name=Duda --bot-lag=0 --bot-offset=120 > "$OUT/Duda.log" 2>&1 &
timeout 200 $G --headless -- --qbot=client --bot-name=Mesa --bot-board > "$OUT/Mesa.log" 2>&1 &
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando" | sort | uniq
FAIL=0
for n in host Bia Caio Duda Mesa; do
  grep -q "BOT .*: FIM" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
J=$(grep -o "FIM justos=[0-9]*/[0-9]*" "$OUT/host.log")
echo "$J"
[ -n "$J" ] && [ "${J#FIM justos=}" != "0/0" ] && [ "$(echo ${J#FIM justos=} | cut -d/ -f1)" = "$(echo ${J#FIM justos=} | cut -d/ -f2)" ] || { echo "FALHA: nem toda corrida foi justa"; FAIL=1; }
grep -q "\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "QUEM FOI REDE OK" || echo "logs em $OUT"
exit $FAIL
