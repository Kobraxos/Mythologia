class_name ActionBar
extends PanelContainer

## Widget UI autonome gérant les boutons de compétences et leurs raccourcis clavier.

@export var skill_button_prefab: PackedScene
@export var skill_container: HBoxContainer
@export var move_button: SystemActionButton

func setup(skills: Array, caster: Node = null) -> void:
	clear()
	
	if not skill_button_prefab:
		push_error("ActionBar: 'skill_button_prefab' manquant.")
		return
		
	if not skill_container:
		push_error("ActionBar: 'skill_container' manquant.")
		return
		
	for i: int in range(skills.size()):
		var skill_res := skills[i] as SkillData
		if not skill_res:
			continue
			
		var btn: SkillButton = skill_button_prefab.instantiate() as SkillButton
		skill_container.add_child(btn)
		
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
			
		btn.setup(skill_res, caster, shortcut_text)
		
	visible = true

func clear() -> void:
	if not skill_container: return
	for child: Node in skill_container.get_children():
		if child is SkillButton:
			child.hide()
			child.queue_free()
	# No need to change visible = false because we might still want to see the move button
	# but actually action_bar might hide entirely if no unit is selected.
	visible = false

func update_usable_skills(available_ap: int, cooldowns: Dictionary = {}) -> void:
	if not skill_container: return
	for child: Node in skill_container.get_children():
		if child is SkillButton:
			if child.is_queued_for_deletion():
				continue
			var current_cd: int = cooldowns.get(child._skill, 0) if child._skill else 0
			child.check_usability(available_ap, current_cd)

func set_all_disabled(is_disabled: bool) -> void:
	if not skill_container: return
	for child: Node in skill_container.get_children():
		if child is SkillButton:
			if child.is_queued_for_deletion():
				continue
			child.disabled = is_disabled
