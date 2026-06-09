class_name TooltipPanel
extends PanelContainer

@export var title_label: Label
@export var description_label: RichTextLabel
@export var cost_label: Label
@export var cooldown_label: Label

func setup(data: Dictionary) -> void:
	if data.has("title"):
		title_label.text = str(data["title"])
	else:
		title_label.text = ""
		
	if data.has("description"):
		description_label.text = str(data["description"])
	else:
		description_label.text = ""
		
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
