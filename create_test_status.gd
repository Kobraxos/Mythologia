@tool
extends SceneTree

func _init():
	var status = StatusEffectData.new()
	status.id = &"test_stun"
	status.effect_name = "Eblouissement Divin"
	status.description = "Etourdi par la lumiere. Ne peut pas agir au prochain tour."
	status.type = StatusEffectData.EffectType.DEBUFF
	status.duration_in_turns = 1
	status.merge_strategy = StatusEffectData.MergeStrategy.REPLACE
	status.is_stunned = true
	
	DirAccess.make_dir_absolute("res://data/statuses")
	ResourceSaver.save(status, "res://data/statuses/test_stun_status.tres")
	
	var payload = SkillEffectPayload.new()
	payload.target = SkillEffectPayload.PayloadTarget.MAIN_TARGET
	payload.application_chance = 1.0
	payload.condition = SkillEffectPayload.TriggerCondition.ALWAYS
	payload.status_effect = status
	
	DirAccess.make_dir_absolute("res://data/skills/payloads")
	ResourceSaver.save(payload, "res://data/skills/payloads/rayon_solaire_stun_payload.tres")
	
	var rayon_solaire: SkillData = load("res://data/skills/attacks/rayon_solaire.tres")
	if rayon_solaire:
		rayon_solaire.effect_payloads.clear()
		rayon_solaire.effect_payloads.append(payload)
		ResourceSaver.save(rayon_solaire, "res://data/skills/attacks/rayon_solaire.tres")
		print("Successfully created status, payload, and updated Rayon Solaire.")
	else:
		print("Failed to load rayon_solaire.tres")
		
	quit()
