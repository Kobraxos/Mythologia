class_name CombatSequencer
extends Node

## "Les Yeux" du combat. Dépile les commandes visuelles à l'écran.
## Instancié à la volée par le CombatManager, s'auto-détruit à la fin.

func play_sequence(sequence: Array[VisualCommandGroup], caster: Node3D, skill: SkillData, target_hex: Vector3i) -> void:
	for group: VisualCommandGroup in sequence:
		await _play_group(group)

	# 100% des animations sont terminées. On libère le tour.
	CombatEvents.skill_resolved.emit(caster, skill, target_hex)
	queue_free()

func _play_group(group: VisualCommandGroup) -> void:
	if group.commands.is_empty():
		return

	var max_duration: float = 0.0

	# Exécution parallèle instantanée de toutes les actions du groupe
	for cmd: VisualCommand in group.commands:
		match cmd.type:
			VisualCommand.Type.FORCED_MOVEMENT:
				var unit := cmd.target as Unit
				if is_instance_valid(unit):
					var tw := unit.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					var pos: Vector3 = HexMath.hex_to_world(cmd.target_hex, GridManager.hex_size, GridManager.elevation_step)
					tw.tween_property(unit, "position", pos, cmd.duration)
					max_duration = max(max_duration, cmd.duration)
					
			VisualCommand.Type.PLAY_ANIMATION:
				# TODO : Branchement vers le modèle 3D / AnimationPlayer
				max_duration = max(max_duration, cmd.duration)
				
			VisualCommand.Type.DAMAGE_NUMBER:
				var is_crit: bool = (cmd.string_payload == "CRIT")
				var is_heal: bool = (cmd.string_payload == "HEAL")
				var is_dodge: bool = (cmd.string_payload == "DODGE")
				var is_shield: bool = (cmd.string_payload == "AEGIS")
				
				if CombatEvents.has_user_signal("visual_text_requested"):
					CombatEvents.emit_signal("visual_text_requested", cmd.target, cmd.int_payload, is_crit, is_heal, is_dodge, is_shield)

			VisualCommand.Type.UPDATE_HEALTH_BAR:
				if CombatEvents.has_user_signal("visual_health_updated"):
					var max_hp: int = 1
					if is_instance_valid(cmd.target) and cmd.target.get("health_component") != null:
						max_hp = cmd.target.health_component.get_max_health()
					CombatEvents.emit_signal("visual_health_updated", cmd.target, cmd.int_payload, max_hp)

			VisualCommand.Type.SPAWN_VFX:
				if CombatEvents.has_user_signal("vfx_requested"):
					CombatEvents.emit_signal("vfx_requested", cmd.string_payload, cmd.position_payload, cmd.direction_payload, cmd.target)

	# Attente unique synchronisée sur l'animation la plus longue du groupe
	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout
