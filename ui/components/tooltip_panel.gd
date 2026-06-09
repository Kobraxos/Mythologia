class_name TooltipPanel
extends PanelContainer

signal keyword_hovered(meta: String, global_pos: Vector2)
signal keyword_unhovered(meta: String)
signal panel_mouse_entered(panel: Control)
signal panel_mouse_exited(panel: Control)
signal size_changed_dynamically(panel: Control)

@export var title_label: Label
@export var description_label: RichTextLabel
@export var cost_label: Label
@export var cooldown_label: Label
@export var range_label: Label
@export var aoe_label: Label
@export var icon_rect: TextureRect
@export var category_label: Label
@export var element_label: Label
@export var los_label: Label
@export var warnings_label: Label
@export var advanced_stats_container: VBoxContainer
@export var advanced_label: Label
@export var flavor_text_label: Label

var _current_hovered_meta: String = ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	mouse_entered.connect(func(): panel_mouse_entered.emit(self))
	mouse_exited.connect(func(): panel_mouse_exited.emit(self))
	
	if description_label:
		description_label.meta_hover_started.connect(_on_meta_hover_started)
		description_label.meta_hover_ended.connect(_on_meta_hover_ended)
		description_label.mouse_exited.connect(_on_rich_text_label_mouse_exited)

func _process(_delta: float) -> void:
	if not visible or not is_inside_tree():
		return
		
	var is_advanced = Input.is_action_pressed("tooltip_advanced")
	if advanced_stats_container and advanced_stats_container.visible != is_advanced:
		advanced_stats_container.visible = is_advanced
		await get_tree().process_frame
		size_changed_dynamically.emit(self)

func setup(data: Dictionary) -> void:
	if data.has("title"):
		title_label.text = str(data["title"])
	else:
		title_label.text = ""
		
	if data.has("description"):
		description_label.text = str(data["description"])
	else:
		description_label.text = ""
		
	if data.has("icon") and data["icon"] != null:
		icon_rect.texture = data["icon"]
		icon_rect.visible = true
	else:
		icon_rect.visible = false
		
	if category_label:
		if data.has("category"):
			var cat_str = "ATTACK"
			match int(data["category"]):
				1: cat_str = "SPELL"
				2: cat_str = "SUPPORT"
				3: cat_str = "MOVEMENT"
				4: cat_str = "TERRAIN"
			category_label.text = "[" + cat_str + "]"
			category_label.visible = true
		else:
			category_label.visible = false

	if element_label:
		if data.has("skill_element") and int(data["skill_element"]) > 0:
			element_label.text = "⚡"
			element_label.visible = true
		else:
			element_label.visible = false
			
	if flavor_text_label:
		if data.has("flavor_text") and str(data["flavor_text"]).length() > 0:
			flavor_text_label.text = str(data["flavor_text"])
			flavor_text_label.visible = true
		else:
			flavor_text_label.visible = false
			
	if los_label:
		if data.has("requires_line_of_sight") and not data["requires_line_of_sight"]:
			los_label.text = "👁️❌"
			los_label.visible = true
		else:
			los_label.visible = false
			
	if warnings_label:
		var warnings = ""
		if data.has("smart_targeting") and not data["smart_targeting"]:
			warnings += "⚠️ Peut toucher les alliés (Friendly Fire).\n"
		if data.has("destroys_terrain") and data["destroys_terrain"]:
			warnings += "⚠️ Détruit le terrain ciblé.\n"
		if data.has("is_execution") and data["is_execution"]:
			warnings += "☠️ Mort Définitive.\n"
			
		if warnings.length() > 0:
			warnings_label.text = warnings.strip_edges()
			warnings_label.visible = true
		else:
			warnings_label.visible = false
			
	if advanced_label:
		var adv_text = "Statistiques Avancées:\n"
		var has_adv = false
		if data.has("max_elevation_up"):
			adv_text += "Hauteur Max: +" + str(data["max_elevation_up"]) + "\n"
			has_adv = true
		if data.has("max_elevation_down"):
			adv_text += "Profondeur Max: -" + str(data["max_elevation_down"]) + "\n"
			has_adv = true
		if data.has("armor_penetration_bonus") and float(data["armor_penetration_bonus"]) > 0:
			adv_text += "Pénétration d'Armure: " + str(float(data["armor_penetration_bonus"]) * 100) + "%\n"
			has_adv = true
			
		advanced_label.text = adv_text.strip_edges()
		# Visibilité de l'AdvancedStatsContainer est gérée par _process
		
	var cost_text = ""
	if data.has("ap_cost") and data["ap_cost"] > 0:
		cost_text += str(data["ap_cost"]) + " AP "
	if data.has("mana_cost") and data["mana_cost"] > 0:
		cost_text += str(data["mana_cost"]) + " MP"
	cost_label.text = cost_text.strip_edges()
	cost_label.visible = cost_text.length() > 0
		
	if data.has("cooldown") and data["cooldown"] > 0:
		cooldown_label.text = "CD: " + str(data["cooldown"])
		cooldown_label.visible = true
	else:
		cooldown_label.visible = false
		
	if data.has("min_range") and data.has("max_range"):
		if data["min_range"] == data["max_range"]:
			range_label.text = "Range: " + str(data["max_range"])
		else:
			range_label.text = "Range: " + str(data["min_range"]) + "-" + str(data["max_range"])
	else:
		range_label.visible = false
		
	if data.has("aoe_shape"):
		# Using the enum value mapped to a string for now
		# Enum AreaShape: SINGLE_TARGET, CIRCLE, LINE, CONE, RING, FLOOD_FILL
		var shape = data["aoe_shape"]
		var shape_str = "Single"
		match shape:
			0: shape_str = "Single"
			1: shape_str = "Circle"
			2: shape_str = "Line"
			3: shape_str = "Cone"
			4: shape_str = "Ring"
			5: shape_str = "Flood"
			
		if data.has("aoe_radius") and data["aoe_radius"] > 0:
			shape_str += " " + str(data["aoe_radius"])
		aoe_label.text = "AoE: " + shape_str
	else:
		aoe_label.visible = false

func _on_meta_hover_started(meta: String):
	_current_hovered_meta = meta
	keyword_hovered.emit(meta, get_global_mouse_position())

func _on_meta_hover_ended(meta: String):
	if _current_hovered_meta != "":
		keyword_unhovered.emit(meta)
	_current_hovered_meta = ""

func _on_rich_text_label_mouse_exited():
	if _current_hovered_meta != "":
		keyword_unhovered.emit(_current_hovered_meta)
		_current_hovered_meta = ""
