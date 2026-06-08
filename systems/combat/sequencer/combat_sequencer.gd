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
					var pos: Vector3 = HexMath.hex_to_world(cmd.target_hex, GridManager.hex_size, GridManager.elevation_step)
					if cmd.duration <= 0.0:
						unit.position = pos
					elif cmd.is_leap:
						var tw := unit.create_tween().set_parallel(true)
						tw.tween_property(unit, "position:x", pos.x, cmd.duration).set_trans(Tween.TRANS_LINEAR)
						tw.tween_property(unit, "position:z", pos.z, cmd.duration).set_trans(Tween.TRANS_LINEAR)
						
						# Arc parabolique : monte puis descend
						var peak_y: float = maxf(unit.position.y, pos.y) + 2.0 # +2 mètres de hauteur au-dessus du plus haut
						var up_tw := unit.create_tween()
						up_tw.tween_property(unit, "position:y", peak_y, cmd.duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						up_tw.tween_property(unit, "position:y", pos.y, cmd.duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						max_duration = max(max_duration, cmd.duration)
					else:
						var tw := unit.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						tw.tween_property(unit, "position", pos, cmd.duration)
						max_duration = max(max_duration, cmd.duration)
					
			VisualCommand.Type.PLAY_ANIMATION:
				# TODO : Branchement vers le modèle 3D / AnimationPlayer
				max_duration = max(max_duration, cmd.duration)
				
			VisualCommand.Type.DAMAGE_NUMBER:
				var type: CombatEvents.FloatingTextType = CombatEvents.FloatingTextType.DAMAGE
				if cmd.string_payload == "CRIT": type = CombatEvents.FloatingTextType.CRIT
				elif cmd.string_payload == "HEAL": type = CombatEvents.FloatingTextType.HEAL
				elif cmd.string_payload == "DODGE": type = CombatEvents.FloatingTextType.DODGE
				elif cmd.string_payload == "AEGIS": type = CombatEvents.FloatingTextType.SHIELD
				
				CombatEvents.visual_text_requested.emit(cmd.target, cmd.int_payload, type, cmd.element_payload as CoreEnums.Element)

			VisualCommand.Type.UPDATE_HEALTH_BAR:
				var max_hp: int = 1
				var target_unit := cmd.target as Unit
				if is_instance_valid(target_unit) and target_unit.health_component:
					max_hp = target_unit.health_component.get_max_health()
				if CombatEvents.has_user_signal("visual_health_updated"):
					CombatEvents.emit_signal("visual_health_updated", cmd.target, cmd.int_payload, max_hp)

			VisualCommand.Type.SPAWN_VFX:
				var pos := cmd.position_payload
				var dir := cmd.direction_payload
				
				if is_instance_valid(cmd.target):
					if pos == Vector3.ZERO:
						pos = cmd.target.global_position
						if cmd.string_payload == VfxConstants.IMPACT_HIT:
							pos += Vector3(0, 1.0, 0)
					
					if dir == Vector3.ZERO and is_instance_valid(cmd.source):
						dir = (cmd.target.global_position - cmd.source.global_position).normalized()
						
				# Cas des mouvements (dash/leap)
				if cmd.target_hex != Vector3i.ZERO and is_instance_valid(cmd.target):
					var end_pos := HexMath.hex_to_world(cmd.target_hex, GridManager.hex_size, GridManager.elevation_step)
					dir = (end_pos - cmd.target.global_position).normalized()
					
				# Cas du teleport in
				if cmd.string_payload == VfxConstants.TELEPORT_IN and cmd.target_hex != Vector3i.ZERO:
					pos = HexMath.hex_to_world(cmd.target_hex, GridManager.hex_size, GridManager.elevation_step)
					
				if dir.length_squared() == 0.0:
					dir = Vector3.UP
					
				CombatEvents.vfx_requested.emit(cmd.string_payload, pos, dir, cmd.target)

	# Attente unique synchronisée sur l'animation la plus longue du groupe
	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout
