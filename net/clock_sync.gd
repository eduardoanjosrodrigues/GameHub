class_name ClockSync
extends RefCounted
## Estima o relógio do host a partir de pings (docs/PLANO_HALLI_GALLI.md §5.1).
##
## Cada ping mede: t0 (envio, relógio local), h (relógio do host ao responder), t1 (chegada da
## resposta). Supondo ida e volta iguais, a diferença é h - (t0 + t1) / 2, com erro de no máximo
## metade do tempo de ida e volta. Por isso vale a medição mais rápida entre as recentes.
## Tudo em microssegundos (Time.get_ticks_usec) por dentro; os horários de jogo saem em ms.

const KEEP := 20

var _samples: Array = [] # [{rtt, offset}], mais recente no fim


func add_sample(t0_us: int, host_us: int, t1_us: int) -> void:
	var rtt := t1_us - t0_us
	if rtt < 0:
		return
	_samples.append({"rtt": rtt, "offset": host_us - (t0_us + t1_us) / 2})
	if _samples.size() > KEEP:
		_samples.pop_front()


func synced() -> bool:
	return _samples.size() >= 3


func sample_count() -> int:
	return _samples.size()


## Diferença estimada (host - local) em µs: a da medição com menor ida e volta.
func offset_us() -> int:
	var best := {}
	for s in _samples:
		if best.is_empty() or s.rtt < best.rtt:
			best = s
	return int(best.offset) if not best.is_empty() else 0


## Converte um instante local (µs) pro relógio do host (ms).
func to_host_ms(local_us: int) -> int:
	return (local_us + offset_us()) / 1000


func host_now_ms() -> int:
	return to_host_ms(Time.get_ticks_usec())


## Ida e volta da última medição (ms), pra mostrar "sinal fraco".
func last_rtt_ms() -> int:
	return int(_samples.back().rtt) / 1000 if not _samples.is_empty() else 0


## Maior ida e volta entre as últimas medições (ms): o host usa pra dimensionar a janela do sino.
func recent_max_rtt_ms(count := 8) -> int:
	var m := 0
	for i in range(maxi(0, _samples.size() - count), _samples.size()):
		m = maxi(m, int(_samples[i].rtt))
	return m / 1000
