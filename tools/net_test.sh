#!/usr/bin/env bash
# Teste de rede: 1 host + 3 clientes robôs jogam uma partida inteira em localhost.
# Um cliente derruba a própria conexão no meio; um quinto tenta entrar atrasado.
# Uso: tools/net_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
$G --headless -- --bot=host --bot-name=Host --bot-team=azul > "$OUT/host.log" 2>&1 &
HOST=$!
sleep 2
$G --headless -- --bot=client --bot-name=Bia --bot-team=azul > "$OUT/bia.log" 2>&1 &
$G --headless -- --bot=client --bot-name=Caio --bot-team=vermelho --bot-drop > "$OUT/caio.log" 2>&1 &
$G --headless -- --bot=client --bot-name=Duda --bot-team=vermelho > "$OUT/duda.log" 2>&1 &
sleep 6
$G --headless -- --bot=client --bot-name=Atrasado --bot-late > "$OUT/late.log" 2>&1 &
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|derrubando|conexão|player_connection" | sort | uniq
FAIL=0
for n in host bia caio duda; do
  grep -q "FIM vencedor" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log | grep -v "Atrasado" && FAIL=1
grep -q "ENCERRADO: A partida já começou" "$OUT/late.log" || { echo "FALHA: atrasado não foi recusado"; FAIL=1; }
grep -q "player_connection.*\"connected\":false" "$OUT/host.log" || { echo "FALHA: host não viu a queda"; FAIL=1; }
grep -q "player_connection.*\"connected\":true" "$OUT/host.log" || { echo "FALHA: host não viu a volta"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "REDE OK" || echo "logs em $OUT"
exit $FAIL
