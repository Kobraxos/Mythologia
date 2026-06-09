extends CanvasLayer

var _tooltip_scene: PackedScene = preload("res://ui/components/tooltip_panel.tscn")
var _current_tooltip: Control
var _debounce_timer: Timer

var _pending_data: Dictionary
var _pending_pos: Vector2
var _pending_size: Vector2

func _ready() -> void:
	layer = 100
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = 0.2
	_debounce_timer.timeout.connect(_on_timer_timeout)
	add_child(_debounce_timer)

func show_tooltip(data_dict: Dictionary, source_pos: Vector2, source_size: Vector2) -> void:
	_pending_data = data_dict
	_pending_pos = source_pos
	_pending_size = source_size
	_debounce_timer.start()

func hide_tooltip() -> void:
	_debounce_timer.stop()
	if _current_tooltip:
		_current_tooltip.queue_free()
		_current_tooltip = null

func _on_timer_timeout() -> void:
	if _current_tooltip:
		_current_tooltip.queue_free()
		
	_current_tooltip = _tooltip_scene.instantiate()
	add_child(_current_tooltip)
	
	if _current_tooltip.has_method("setup"):
		_current_tooltip.setup(_pending_data)
	
	# Hide for one frame to allow container sizing to update
	_current_tooltip.modulate.a = 0.0 
	
	await get_tree().process_frame
	
	if is_instance_valid(_current_tooltip):
		_apply_smart_positioning(_pending_pos, _pending_size)
		_current_tooltip.modulate.a = 1.0

func _apply_smart_positioning(source_pos: Vector2, source_size: Vector2) -> void:
	var tooltip_size = _current_tooltip.size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Default position: Centered above the button
	var pos_x = source_pos.x + (source_size.x / 2.0) - (tooltip_size.x / 2.0)
	var pos_y = source_pos.y - tooltip_size.y - 10 # 10px margin
	
	# Clamping X
	if pos_x < 10:
		pos_x = 10
	elif pos_x + tooltip_size.x > viewport_size.x - 10:
		pos_x = viewport_size.x - tooltip_size.x - 10
		
	# Clamping Y (if above goes off-screen, put it below the button)
	if pos_y < 10:
		pos_y = source_pos.y + source_size.y + 10
		
	_current_tooltip.global_position = Vector2(pos_x, pos_y)
