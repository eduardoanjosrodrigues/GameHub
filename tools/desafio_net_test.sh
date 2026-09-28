#!/usr/bin/env bash
# Teste de rede do Wordle e do Senha (docs/PLANO_WORDLE_SENHA.md §5, §8): 1 host + robôs jogam uma
# partida inteira. Na Corrida, um robô derruba a própria conexão no meio e volta.
# Uso: tools/desafio_net_test.sh wordle|senha [corrida|duelo] [tentativas|primeiro|pontos] [caminho do godot]
set -u
GAME="${1:-wordle}"
MODE="${2:-corrida}"
CRIT="${3:-tentativas}"
G="${4:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
if [ "$MODE" = "duelo" ]; then NAMES="Bia"; N=2; else NAMES="Bia Caio Gil"; N=4; fi
timeout 200 $G --headless -- --dbot=host --bot-game=$GAME --bot-name=Host --bot-players=$N --bot-mode=$MODE --bot-crit=$CRIT > "$OUT/host.log" 2>&1 &
sleep 2
for n in $NAMES; do
  EXTRA=""
  [ "$n" = "Gil" ] && EXTRA="--bot-drop"
  timeout 200 $G --headless -- --dbot=client --bot-game=$GAME --bot-name=$n $EXTRA > "$OUT/$n.log" 2>&1 &
done
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando" | sort | uniq
FAIL=0
for n in host $NAMES; do
  grep -q "BOT .*: FIM" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
if [ "$MODE" != "duelo" ]; then
  grep -q "\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
fi
[ $FAIL -eq 0 ] && echo "$(echo $GAME | tr a-z A-Z) $MODE REDE OK" || echo "logs em $OUT"
exit $FAIL
