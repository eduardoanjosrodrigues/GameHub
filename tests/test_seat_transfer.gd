extends TestCase
## Testes da troca de aparelho no meio da partida (net/seat_transfer.gd).

var seats := ["ana", "bia", "caio"]


func _has(id: String) -> bool:
	return id in seats


func test_normal_devices_keep_their_seat() -> void:
	var st := SeatTransfer.new()
	var r := st.on_hello("ana", "", _has, 0)
	check(r.seat == "ana" and not r.taken, "sem QR, o aparelho é a própria vaga")


func test_new_device_takes_seat_and_old_loses_it() -> void:
	var st := SeatTransfer.new()
	var t := st.issue("ana", 0)
	var r := st.on_hello("novo", t, _has, 1000)
	check(r.get("seat", "") == "ana" and r.taken, "o aparelho novo assume a vaga")
	var old := st.on_hello("ana", "", _has, 2000)
	check(old.get("erro", "") == "vaga_passada", "o aparelho antigo perde a vaga")
	var again := st.on_hello("novo", "", _has, 3000)
	check(again.get("seat", "") == "ana" and not again.taken, "o aparelho novo reconecta sem QR")
	var same := st.on_hello("novo", t, _has, 4000)
	check(same.get("seat", "") == "ana", "e também pelo mesmo link (recarregou a página)")


func test_token_single_use_and_expires() -> void:
	var st := SeatTransfer.new()
	var t := st.issue("bia", 0)
	st.on_hello("x", t, _has, 10)
	check(st.on_hello("y", t, _has, 20).get("erro", "") == "vaga_invalida", "QR usado não serve pra outro aparelho")
	var t2 := st.issue("caio", 0)
	check(st.on_hello("z", t2, _has, SeatTransfer.TTL_MS + 1).get("erro", "") == "vaga_invalida", "QR vencido")
	check(st.on_hello("z", "inventado", _has, 0).get("erro", "") == "vaga_invalida", "token desconhecido")


func test_device_already_playing_cannot_take_other_seat() -> void:
	var st := SeatTransfer.new()
	var t := st.issue("ana", 0)
	check(st.on_hello("bia", t, _has, 10).get("erro", "") == "vaga_invalida", "a Bia não vira a Ana")
	check(st.on_hello("bia", "", _has, 20).get("seat", "") == "bia", "e continua sendo a Bia")


func test_original_device_can_take_seat_back() -> void:
	var st := SeatTransfer.new()
	st.on_hello("novo", st.issue("ana", 0), _has, 10)
	var r := st.on_hello("ana", st.issue("ana", 20), _has, 30)
	check(r.get("seat", "") == "ana" and r.taken, "o celular original volta com um QR novo")
	check(st.on_hello("novo", "", _has, 40).get("erro", "") == "vaga_passada", "e o emprestado perde a vaga")


func test_new_qr_replaces_unused_one() -> void:
	var st := SeatTransfer.new()
	var t1 := st.issue("ana", 0)
	var t2 := st.issue("ana", 10)
	check(st.on_hello("x", t1, _has, 20).get("erro", "") == "vaga_invalida", "o QR antigo, não usado, deixa de valer")
	check(st.on_hello("x", t2, _has, 30).get("seat", "") == "ana", "o novo vale")
