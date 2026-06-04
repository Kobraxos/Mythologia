class_name ActionBar
extends HBoxContainer

## Widget UI autonome gérant les boutons de compétences et leurs raccourcis clavier.

@export var skill_button_prefab: PackedScene

func setup(skills: Array) -> void:
	clear()
	
	if not skill_button_prefab:
		push_error("ActionBar: 'skill_button_prefab' manquant.")
		return
		
	for i: int in range(skills.size()):
		var skill_res := skills[i] as SkillData
		if not skill_res:
			continue
			
		var btn: SkillButton = skill_button_prefab.instantiate() as SkillButton
		add_child(btn)
		
		# Assignation dynamique du raccourci AAA (Input Map)
		var action_name: String = "skill_" + str(i + 1)
		var shortcut_text: String = ""
		
		if InputMap.has_action(action_name):
			var shortcut := Shortcut.new()
			var event := InputEventAction.new()
			event.action = action_name
			shortcut.events.append(event)
			btn.shortcut = shortcut
			shortcut_text = str(i + 1)
			
		btn.setup(skill_res, shortcut_text)
		
	visible = true

func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	visible = false

func update_usable_skills(available_ap: int, cooldowns: Dictionary = {}) -> void:
	for child: Node in get_children():
		if child is SkillButton:
			var current_cd: int = cooldowns.get(child._skill, 0) if child._skill else 0
			child.check_usability(available_ap, current_cd)