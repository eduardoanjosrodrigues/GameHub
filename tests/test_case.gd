class_name TestCase
extends RefCounted

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual, expected, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: esperado %s, veio %s" % [msg, str(expected), str(actual)])
