class_name MaxWidth
extends Container
## Centraliza os filhos com largura máxima (conteúdo não estica demais no tablet).

var max_width := Tokens.CONTENT_MAX_WIDTH


func _init(p_max := Tokens.CONTENT_MAX_WIDTH) -> void:
	max_width = p_max


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var w: float = min(size.x, max_width)
		for c in get_children():
			if c is Control and c.visible:
				fit_child_in_rect(c, Rect2((size.x - w) / 2.0, 0, w, size.y))


func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		if c is Control and c.visible:
			m = m.max(c.get_combined_minimum_size())
	m.x = min(m.x, max_width)
	return m
