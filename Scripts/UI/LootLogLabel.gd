extends Label

var item_name: String = ""
var current_count: int = 0
var timer: Timer

func setup(p_id: String, p_amount: int):
	item_name = p_id.capitalize().replace("_", " ")
	current_count = p_amount
	_refresh_text()
	
	# Style
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	
	# Timer interne
	timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)
	timer.start()

func add_amount(amount: int):
	current_count += amount
	_refresh_text()
	
	# On reset le timer pour laisser le texte affiché plus longtemps
	timer.start()
	
	# Effet Pop
	scale = Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)

func _refresh_text():
	text = "+ " + str(current_count) + " " + item_name

func _on_timeout():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
