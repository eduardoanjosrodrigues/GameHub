extends TestCase
## Testes do relógio sincronizado (docs/PLANO_HALLI_GALLI.md §5.1, marco H3).


## Simula pings com atraso de ida e de volta sorteados (base + cauda exponencial).
func _simulate(offset_us: int, base_ms: float, mean_extra_ms: float, count: int, seed_value: int) -> ClockSync:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cs := ClockSync.new()
	var local := 1_000_000
	for i in count:
		var up := int((base_ms + -mean_extra_ms * log(1.0 - rng.randf())) * 1000.0)
		var down := int((base_ms + -mean_extra_ms * log(1.0 - rng.randf())) * 1000.0)
		var t0 := local
		var host := t0 + up + offset_us
		var t1 := t0 + up + down
		cs.add_sample(t0, host, t1)
		local = t1 + 500_000
	return cs


func test_offset_on_home_wifi() -> void:
	# Wi-Fi de casa: atraso extra médio de até 15 ms em cada sentido -> erro abaixo de 5 ms.
	for seed_value in [1, 2, 3, 4, 5]:
		for mean in [2.0, 6.0, 15.0]:
			var cs := _simulate(-123_456_789, 3.0, mean, 20, seed_value)
			var err := absi(cs.offset_us() - (-123_456_789))
			check(err < 5000, "erro de %d µs com média extra %.0f ms (semente %d)" % [err, mean, seed_value])


func test_offset_on_bad_network() -> void:
	# Rede ruim (economia de energia do Wi-Fi, média extra de 60 ms): erro ainda abaixo de 20 ms.
	for seed_value in [1, 2, 3, 4, 5]:
		var cs := _simulate(987_654, 3.0, 60.0, 20, seed_value)
		var err := absi(cs.offset_us() - 987_654)
		check(err < 20000, "erro de %d µs (semente %d)" % [err, seed_value])


func test_needs_three_samples() -> void:
	var cs := ClockSync.new()
	check(not cs.synced(), "sem medições")
	cs.add_sample(0, 10_000, 2_000)
	cs.add_sample(0, 10_000, 2_000)
	check(not cs.synced(), "2 medições ainda não")
	cs.add_sample(0, 10_000, 2_000)
	check(cs.synced(), "3 medições")
	eq(cs.offset_us(), 9_000, "diferença calculada")
	eq(cs.to_host_ms(1_000_000), 1009, "converte pro relógio do host")


func test_keeps_recent_samples_only() -> void:
	var cs := ClockSync.new()
	cs.add_sample(0, 50_000, 1_000) # muito rápida, mas vai sair da janela
	for i in ClockSync.KEEP:
		cs.add_sample(0, 20_000, 10_000)
	eq(cs.offset_us(), 15_000, "a medição antiga saiu")
	eq(cs.recent_max_rtt_ms(), 10, "maior ida e volta recente")
