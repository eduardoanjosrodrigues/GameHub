#!/usr/bin/env bash
# Teste de "Trocar aparelho" no Avalon: a Eva some de vez no meio da partida; o tabuleiro abre o QR
# da vaga dela; um aparelho novo entra por ele e termina a partida no lugar dela. Depois o aparelho
# antigo da Eva tenta voltar e é recusado.
# Uso: tools/avalon_swap_test.sh [caminho do godot]
set -u
G="${1:-${GODOT:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
BOT_CONTINUE_MS=1500 $G --headless -- --abot=host --bot-name=Host --bot-players=5 > "$OUT/host.log" 2>&1 &
sleep 2
for n in Bia Caio Duda; do
  $G --headless -- --abot=client --bot-name=$n > "$OUT/$n.log" 2>&1 &
done
$G --headless -- --abot=client --bot-name=Eva --bot-die > "$OUT/Eva.log" 2>&1 &
BOT_CONTINUE_MS=1500 $G --headless -- --abot=client --bot-name=Mesa --bot-board --bot-swapper > "$OUT/Mesa.log" 2>&1 &
TOKEN=""
for i in $(seq 1 120); do
  TOKEN=$(grep -h "BOT Mesa: VAGA bot-Eva" "$OUT/Mesa.log" | awk '{print $5}' | head -1)
  [ -n "$TOKEN" ] && break
  sleep 0.5
done
[ -z "$TOKEN" ] && { echo "FALHA: o tabuleiro não recebeu o QR"; echo "logs em $OUT"; kill $(jobs -p) 2>/dev/null; exit 1; }
echo "QR da vaga da Eva: $TOKEN"
$G --headless -- --abot=client --bot-name=Novo --bot-seat=$TOKEN > "$OUT/Novo.log" 2>&1 &
sleep 1
# O aparelho antigo da Eva volta (bateria carregou): tem que ser recusado.
$G --headless -- --abot=client --bot-name=Eva > "$OUT/Eva2.log" 2>&1 &
wait
echo "== resultado =="
grep -h "BOT" "$OUT"/*.log | grep -E "FIM|ERRO|ENCERRADO|TIMEOUT|morrendo|VAGA" | sort | uniq
FAIL=0
for n in host Bia Caio Duda Mesa Novo; do
  grep -q "FIM vencedor" "$OUT/$n.log" || { echo "FALHA: $n não terminou a partida"; FAIL=1; }
done
grep -q "passado para outro aparelho" "$OUT/Eva2.log" || { echo "FALHA: o aparelho antigo não foi recusado"; FAIL=1; }
grep -h "BOT .*ERRO\|SCRIPT ERROR" "$OUT"/*.log && FAIL=1
[ $FAIL -eq 0 ] && echo "TROCA DE APARELHO OK" || echo "logs em $OUT"
exit $FAIL
