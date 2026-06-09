extends CanvasLayer

var _tooltip_scene: PackedScene = preload("res://ui/components/tooltip_panel.tscn")
var _active_tooltips: Array[Control] = []
var _grace_timer: Timer
var _debounce_timer: Timer

var _pending_data: Dictionary
var _pending_pos: Vector2
var _pending_size: Vector2

func _ready() -> void:
	layer = 100
	
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = 0.2
	_debounce_timer.timeout.connect(_on_debounce_timer_timeout)
	add_child(_debounce_timer)
	
	_grace_timer = Timer.new()
	_grace_timer.one_shot = true
	_grace_timer.timeout.connect(_on_grace_timer_timeout)
	add_child(_grace_timer)

# --- Primary Tooltip Handling ---

func show_tooltip(data_dict: Dictionary, source_pos: Vector2, source_size: Vector2) -> void:
	_pending_data = data_dict
	_pending_pos = source_pos
	_pending_size = source_size
	_debounce_timer.start()

func hide_tooltip() -> void:
	_debounce_timer.stop()
	_close_tooltips_from_index(0)

func _on_debounce_timer_timeout() -> void:
	_close_tooltips_from_index(0)
	_instantiate_tooltip(_pending_data, _pending_pos, _pending_size, null)

# --- Sub-Tooltip Handling (Nested) ---

func _on_keyword_hovered(meta: String, global_pos: Vector2, parent_tooltip: Control) -> void:
	_grace_timer.stop()
	
	var index = _active_tooltips.find(parent_tooltip)
	if index != -1:
		# Close existing children of this parent tooltip before opening a new one
		_close_tooltips_from_index(index + 1)
		
	var sub_data = _fetch_data_from_meta(meta)
	if sub_data.is_empty():
		return
		
	var parent_rect = parent_tooltip.get_global_rect()
	_instantiate_tooltip(sub_data, parent_rect.position, parent_rect.size, parent_tooltip)

func _on_keyword_unhovered(meta: String) -> void:
	_grace_timer.start(0.3)

# --- Common Instantiation ---

func _instantiate_tooltip(data: Dictionary, source_pos: Vector2, source_size: Vector2, parent_tooltip: Control = null) -> void:
	var tooltip = _tooltip_scene.instantiate()
	add_child(tooltip)
	_active_tooltips.append(tooltip)
	
	if tooltip.has_method("setup"):
		tooltip.setup(data)
		
	tooltip.keyword_hovered.connect(func(meta, pos): _on_keyword_hovered(meta, pos, tooltip))
	tooltip.keyword_unhovered.connect(_on_keyword_unhovered)
	tooltip.panel_mouse_entered.connect(_on_tooltip_mouse_entered)
	tooltip.panel_mouse_exited.connect(_on_tooltip_mouse_exited)
	
	tooltip.modulate.a = 0.0 
	
	await get_tree().process_frame
	
	if is_instance_valid(tooltip):
		if parent_tooltip == null:
			_apply_smart_positioning(tooltip, source_pos, source_size)
		else:
			_apply_side_anchoring(tooltip, source_pos, source_size)
		tooltip.modulate.a = 1.0

# --- Positioning Logic ---

func _apply_smart_positioning(tooltip: Control, source_pos: Vector2, source_size: Vector2) -> void:
	var tooltip_size = tooltip.size
	var viewport_size = get_viewport().get_visible_rect().size
	
	var pos_x = source_pos.x + (source_size.x / 2.0) - (tooltip_size.x / 2.0)
	var pos_y = source_pos.y - tooltip_size.y - 10 
	
	if pos_x < 10: pos_x = 10
	elif pos_x + tooltip_size.x > viewport_size.x - 10: pos_x = viewport_size.x - tooltip_size.x - 10
		
	if pos_y < 10: pos_y = source_pos.y + source_size.y + 10
		
	tooltip.global_position = Vector2(pos_x, pos_y)

func _apply_side_anchoring(tooltip: Control, parent_pos: Vector2, parent_size: Vector2) -> void:
	var child_size = tooltip.size
	var viewport_size = get_viewport().get_visible_rect().size
	var padding = 10
	
	# Try placing it to the right
	var pos_x = parent_pos.x + parent_size.x + padding
	if pos_x + child_size.x > viewport_size.x - padding:
		# If it overflows right, place it to the left
		pos_x = parent_pos.x - child_size.x - padding
		
	var pos_y = parent_pos.y
	if pos_y + child_size.y > viewport_size.y - padding:
		pos_y = viewport_size.y - child_size.y - padding
		
	if pos_y < padding: pos_y = padding
		
	tooltip.global_position = Vector2(pos_x, pos_y)

# --- Grace Timer and Mouse Events ---

func _on_tooltip_mouse_entered(tooltip_instance: Control) -> void:
	_grace_timer.stop()

func _on_tooltip_mouse_exited(tooltip_instance: Control) -> void:
	var index = _active_tooltips.find(tooltip_instance)
	if index != -1:
		_close_tooltips_from_index(index)

func _on_grace_timer_timeout() -> void:
	if _active_tooltips.size() > 1:
		var top_tooltip = _active_tooltips.pop_back()
		top_tooltip.queue_free()

func _close_tooltips_from_index(index: int) -> void:
	while _active_tooltips.size() > index:
		var t = _active_tooltips.pop_back()
		t.queue_free()

# --- Mock Domain Service (DDD) ---

func _fetch_data_from_meta(meta: String) -> Dictionary:
	# Format expected: "domain:id" e.g., "status:burn"
	var parts = meta.split(":")
	if parts.size() < 2: return {}
	
	var domain = parts[0]
	var id = parts[1]
	
	if domain == "status":
		return {
			"title": id.capitalize(),
			"description": "Explication détaillée de l'effet " + id + "."
		}
	
	return {}
