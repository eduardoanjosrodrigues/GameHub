extends SceneTree
## Executor de testes simples. Rode com:
##   godot --headless -s res://tests/run_tests.gd
## Cada arquivo tests/test_*.gd estende TestCase e tem métodos test_*.

func _init() -> void:
	var files := DirAccess.get_files_at("res://tests")
	var total := 0
	var failed := 0
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: Script = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			print("  FALHA %s :: não compilou" % f)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var tc: TestCase = script.new()
			tc.call(name)
			total += 1
			if tc.failures.is_empty():
				print("  ok    %s :: %s" % [f, name])
			else:
				failed += 1
				print("  FALHA %s :: %s" % [f, name])
				for msg in tc.failures:
					print("        - " + msg)
	print("\n%d testes, %d falhas" % [total, failed])
	quit(1 if failed > 0 else 0)
