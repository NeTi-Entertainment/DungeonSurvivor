extends VBoxContainer

var log_label_script = preload("res://Scripts/UI/LootLogLabel.gd")
var active_logs = {}
var log_duration = 3.0

func _ready():
	GameData.loot_collected.connect(_on_loot_collected)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_loot_collected(item_id: String, amount: int):
	if item_id in active_logs and is_instance_valid(active_logs[item_id]):
		active_logs[item_id].add_amount(amount)
	else:
		var label = Label.new()
		label.set_script(log_label_script)
		add_child(label)
		move_child(label, 0) 
		
		label.setup(item_id, amount)
		label.tree_exiting.connect(func(): 
			if item_id in active_logs:
				active_logs.erase(item_id)
		)
		active_logs[item_id] = label

func _create_new_log_entry(item_id: String, amount: int):
	var label = Label.new()
	
	add_child(label)
	label.text = "+ " + str(amount) + " " + item_id.capitalize() # "iron_scrap" -> "Iron Scrap"
	label.set("theme_override_colors/font_outline_color", Color.BLACK)
	label.set("theme_override_constants/outline_size", 4)
	
	label.set_meta("current_count", amount)
	label.set_meta("item_name", item_id.capitalize())
	label.set_meta("id", item_id)
	
	active_logs[item_id] = label
	
	var timer = get_tree().create_timer(log_duration)
	timer.timeout.connect(func(): _remove_log(item_id, label))
	
	label.set_script(preload("res://Scripts/UI/LootLogLabel.gd")) 

func _remove_log(item_id: String, label: Label):
	if item_id in active_logs and active_logs[item_id] == label:
		active_logs.erase(item_id)
	
	if is_instance_valid(label):
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)
