#!/usr/bin/env bash
# Teste de rede da Corrida do Genius: 1 host + 3 robôs jogam uma partida inteira.
# Rodada 2: todos erram (a rodada se repete). Bia sai na 3, Duda na 4, Caio na 5 (e Caio derruba
# a própria conexão na 3 e volta). O host tem que vencer, na ordem Host, Caio, Duda, Bia.
# Uso: tools/genius_net_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
timeout 200 $G --headless -- --gbot=host --bot-name=Host --bot-players=4 --bot-fail=2 > "$OUT/host.log" 2>&1 &
sleep 2
timeout 200 $G --headless -- --gbot=client --bot-name=Bia --bot-fail=2,3 --bot-lag=120 > "$OUT/Bia.log" 2>&1 &
timeout 200 $G --headless -- --gbot=client --bot-name=Caio --bot-fail=2,5 --bot-drop --bot-lag=40 > "$OUT/Caio.log" 2>&1 &
timeout 200 $G --headless -- --gbot=client --bot-name=Duda --bot-fail=2,4 > "$OUT/Duda.log" 2>&1 &
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando" | sort | uniq
FAIL=0
for n in host Bia Caio Duda; do
  grep -q "BOT .*: FIM" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
grep -q "FIM ranking=1:Host,2:Caio,3:Duda,4:Bia repeticoes=1" "$OUT/host.log" || { echo "FALHA: classificação ou repetição errada"; FAIL=1; }
grep -q "\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "GENIUS REDE OK" || echo "logs em $OUT"
exit $FAIL
