extends Node

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const ROBBER_SCENE: PackedScene = preload("res://actors/enemy/enemy.tscn")
const ImpactSlashType := preload("res://fx/impact_slash_3d.gd")

var _failures := 0
var _phases: Array[StringName] = []
var _spawned: Array[Dictionary] = []

func _ready() -> void:
	var player := PLAYER_SCENE.instantiate() as Node3D
	var robber := ROBBER_SCENE.instantiate() as Node3D
	add_child(player)
	add_child(robber)
	var side_camera := Camera3D.new()
	add_child(side_camera)
	side_camera.position = Vector3(0.45, 1.1, 3.0)
	side_camera.look_at(Vector3(0.45, 1.1, 0.0), Vector3.UP)
	side_camera.make_current()
	# プレイヤーは +X を向く（ベルトスクロール化）。判定球は本体の +0.5 X にある。
	robber.position = Vector3(0.9, 0, 0)
	await get_tree().physics_frame
	var melee := player.get_node(^"PlayerMelee")
	var hitbox := player.get_node(^"Model/MeleeHitbox") as Hitbox
	var hurtbox := robber.get_node(^"Hurtbox") as Hurtbox
	var slash := player.get_node(^"ImpactSlash3D") as ImpactSlashType
	slash.phase_spawned.connect(func(_technique: StringName, phase: StringName) -> void: _phases.append(phase))
	slash.slash_spawned.connect(func(technique: StringName, position: Vector3, shape: int) -> void: _spawned.append({"technique": technique, "position": position, "shape": shape}))

	melee.emit_signal("stage_started", &"jab", 1)
	_check(_phases.is_empty() \
			and slash.get_node_or_null(^"Stage1Spear") == null \
			and slash.get_node_or_null(^"JabLeadSmear") == null,
		"jab shows no VFX before a confirmed hit")
	_land(hitbox, hurtbox)
	var first_impact_position := hurtbox.last_melee_impact_position()
	_check(slash.get_node_or_null(^"JabLeadSmear") != null \
			and slash.get_node_or_null(^"JabLeadCoreGlow") != null \
			and slash.get_node_or_null(^"JabLeadLowerTip") != null \
			and slash.get_node_or_null(^"JabLeadUpperTip") == null \
			and slash.get_node_or_null(^"ImpactSmear") == null \
			and _phases.has(&"jab_frame_1") \
			and (slash.get_node(^"JabLeadSmear") as MeshInstance3D).transparency > 0.9,
		"jab hit starts reference frame 1")
	var jab_lead := slash.get_node(^"JabLeadSmear") as MeshInstance3D
	var jab_halo := slash.get_node(^"JabLeadHalo") as MeshInstance3D
	var jab_lower_tip := slash.get_node(^"JabLeadLowerTip") as MeshInstance3D
	var jab_lead_size := (jab_lead.mesh as QuadMesh).size
	var jab_halo_size := (jab_halo.mesh as QuadMesh).size
	var jab_lower_tip_size := (jab_lower_tip.mesh as QuadMesh).size
	var jab_direction: Vector3 = slash.call("_attack_direction", robber)
	var jab_lower_tip_anchor := jab_lower_tip.global_position \
		+ jab_direction * jab_lower_tip_size.x * 0.5 \
		+ Vector3.UP * slash.jab_lead_tip_vertical_offset
	var expected_jab_tip := first_impact_position \
		+ jab_direction * slash.jab_lead_tip_penetration
	var jab_lead_material := (jab_lead.mesh as QuadMesh).material \
		as StandardMaterial3D
	_check(is_equal_approx(jab_lead_size.x,
			slash.spear_length + slash.spear_tip_extension) \
			and is_equal_approx(jab_lead_size.y, jab_lead_size.x * 0.47) \
			and is_equal_approx(jab_halo_size.y, jab_halo_size.x * 1.10) \
			and is_equal_approx(jab_lower_tip_size.x,
				slash.jab_lead_tip_size.x * 1.05) \
			and is_equal_approx(jab_lower_tip_size.y,
				slash.jab_lead_tip_size.y * 1.55) \
			and slash.jab_lead_tip_vertical_offset <= 0.05 \
			and slash.jab_lead_tip_penetration <= 0.0 \
			and jab_lower_tip_anchor.distance_to(expected_jab_tip) < 0.04 \
			and slash.punch_emission_scale >= 0.85 \
			and slash.punch_emission_scale <= 0.90 \
			and absf(jab_lead_material.emission.r \
				- slash.jab_lead_tint.r * slash.jab_lead_emission \
				* slash.punch_emission_scale) < 0.001,
		"jab frame 1 keeps its width and forms one close lower fork beneath its built-in hot core")
	await get_tree().create_timer(slash.jab_frame_interval * 1.25).timeout
	_check(slash.get_node_or_null(^"ImpactSmear") != null \
			and slash.get_node_or_null(^"JabContactGlow") != null \
			and slash.get_node_or_null(^"JabContactBody") != null \
			and slash.get_node_or_null(^"JabContactShadow") != null \
			and slash.get_node_or_null(^"JabContactBurst") != null \
			and slash.get_node_or_null(^"ImpactSmearDark") == null \
			and slash.get_node_or_null(^"JabContactLightning") == null \
			and slash.get_node_or_null(^"ImpactFanRay") == null \
			and slash.get_node_or_null(^"ImpactBloom") == null \
			and slash.get_node_or_null(^"ImpactHotCore") == null \
			and _phases.has(&"jab_frame_2"),
		"jab frame 2 layers an integrated smoky trail with a restrained glow")
	var impact_smear := slash.get_node(^"ImpactSmear") as MeshInstance3D
	var jab_smoke := slash.get_node(^"JabContactSmoke") as MeshInstance3D
	var jab_burst := slash.get_node(^"JabContactBurst") as MeshInstance3D
	var impact_size := (impact_smear.mesh as QuadMesh).size
	var jab_burst_size := (jab_burst.mesh as QuadMesh).size
	var jab_impact_material := (impact_smear.mesh as QuadMesh).material \
		as StandardMaterial3D
	var jab_smoke_material := (jab_smoke.mesh as QuadMesh).material \
		as StandardMaterial3D
	_check(impact_size.is_equal_approx(slash.jab_contact_size) \
			and is_equal_approx(impact_size.x, slash.jab_contact_length) \
			and jab_burst_size.is_equal_approx(slash.jab_contact_burst_size) \
			and jab_impact_material.blend_mode \
			== BaseMaterial3D.BLEND_MODE_ADD \
			and jab_smoke_material.blend_mode \
			== BaseMaterial3D.BLEND_MODE_MIX,
		"reference frame 2 separates additive light from smoky dark mass")
	_check(slash.jab_frame_duration - slash.jab_frame_interval \
			<= 1.0 / 30.0 + 0.0001,
		"jab frame 1 clears before frame 2 finishes instead of thickening its tail")
	_check(slash.jab_frame_duration <= 0.101 \
			and slash.impact_duration <= 0.101 \
			and slash.straight_frame_duration <= 0.135 \
			and slash.straight_contact_duration <= 0.110 \
			and slash.hook_contact_duration <= 0.118 \
			and slash.hook_follow_duration <= 0.135 \
			and slash.ember_lifetime <= 0.145 \
			and slash.lingering_ember_lifetime <= 0.165,
		"all punch layers use a brief fade window instead of a lingering card")
	var damage_feedback := robber.get_node(^"DamageFeedback3D")
	_check(_has_damage_label(damage_feedback) \
			and not _has_legacy_damage_burst(damage_feedback),
		"damage feedback keeps the number without the old mesh or particle burst")
	_check_embers(slash, slash.ember_amount)

	_phases.clear()
	melee.emit_signal("stage_started", &"straight", 2)
	await get_tree().process_frame
	_check(_phases.is_empty(), "straight shows no VFX before a confirmed hit")
	slash.call("_on_impact_landed", robber, first_impact_position)
	_check(slash.get_node_or_null(^"StraightTrailSprite") != null \
			and slash.get_node_or_null(^"StraightVolumeSprite") != null \
			and slash.get_node_or_null(^"StraightCoreSprite") != null \
			and slash.get_node_or_null(^"StraightSmokeSprite") != null \
			and slash.get_node_or_null(^"StraightShadowSprite") == null \
			and slash.get_node_or_null(^"StraightFanRay") == null \
			and slash.get_node_or_null(^"StraightContactBurst") == null \
			and _phases.has(&"straight_frame_3"),
		"straight frame 3 starts with the integrated layered plasma trail")
	var straight_trail := slash.get_node(^"StraightTrailSprite") \
		as MeshInstance3D
	var straight_volume := slash.get_node(^"StraightVolumeSprite") \
		as MeshInstance3D
	var straight_trail_size := (straight_trail.mesh as QuadMesh).size
	var straight_volume_size := (straight_volume.mesh as QuadMesh).size
	var straight_trail_material := (straight_trail.mesh as QuadMesh).material \
		as ShaderMaterial
	var straight_volume_material := (straight_volume.mesh as QuadMesh).material \
		as ShaderMaterial
	var straight_initial_tint: Color = straight_trail_material \
		.get_shader_parameter("frame_tint")
	var straight_direction := robber.global_position - slash.global_position
	straight_direction.y = 0.0
	straight_direction = straight_direction.normalized()
	var straight_trail_contact := straight_trail.global_position \
		+ straight_direction * (slash.straight_trail_contact_u - 0.5) \
		* slash.straight_trail_size.x
	_check(straight_trail_size.is_equal_approx(Vector2(1.68, 0.73)) \
			and slash.straight_trail_size.is_equal_approx(Vector2(1.68, 0.73)) \
			and straight_volume_size.is_equal_approx(straight_trail_size) \
			and straight_volume.global_position.distance_to( \
				straight_trail.global_position) < 0.01 \
			and straight_trail_size.x / straight_trail_size.y > 2.2 \
			and straight_trail_contact.distance_to(first_impact_position) < 0.01 \
			and straight_trail_material != null \
			and straight_volume_material != null \
			and absf(float(straight_trail_material.get_shader_parameter(
				"emission_energy")) - slash.straight_frame_3_emission \
				* 1.20) < 0.001 \
			and absf(straight_initial_tint.r \
				- slash.straight_frame_3_tint.r \
				* slash.punch_emission_scale) < 0.001 \
			and is_equal_approx(float(straight_trail_material \
				.get_shader_parameter("warmth")), slash.straight_frame_3_warmth) \
			and is_equal_approx(float(straight_volume_material \
				.get_shader_parameter("warmth")), slash.straight_frame_3_warmth),
		"straight frame 3 keeps the reference aspect, smoky dark layer, and contact anchor")
	await get_tree().create_timer(slash.straight_frame_interval * 1.25).timeout
	_check(slash.get_node_or_null(^"StraightTrailSprite") != null \
			and slash.get_node_or_null(^"StraightShadowSprite") == null \
			and slash.get_node_or_null(^"StraightContactBurst") != null \
			and slash.get_node_or_null(^"StraightFanRay") == null \
			and slash.get_node_or_null(^"StraightImpactCore") == null \
			and is_equal_approx(float(straight_trail_material \
				.get_shader_parameter("warmth")), slash.straight_frame_4_warmth) \
			and is_equal_approx(float(straight_volume_material \
				.get_shader_parameter("warmth")), slash.straight_frame_4_warmth) \
			and _phases.has(&"straight_frame_4"),
		"straight frame 4 turns the same trail yellow and adds only the contact fracture")
	var straight_contact := slash.get_node(^"StraightContactBurst") \
		as MeshInstance3D
	var straight_contact_size := (straight_contact.mesh as QuadMesh).size
	var straight_contact_anchor := straight_contact.global_position \
		+ straight_direction * (slash.straight_contact_core_u - 0.5) \
		* slash.straight_contact_size.x
	_check(straight_contact_size.is_equal_approx(slash.straight_contact_size) \
			and straight_contact_anchor.distance_to(first_impact_position) < 0.01 \
			and straight_contact_size.x < straight_trail_size.x * 0.55,
		"straight frame 4 uses a compact asymmetric fracture at the hit point")
	_check(slash.get_node_or_null(^"Stage2Star") == null \
			and slash.get_node_or_null(^"Stage2OrangeGlow") == null \
			and slash.get_node_or_null(^"Stage2JaggedFlame") == null,
		"stage 2 does not reproduce the reference video's uppercut-only effect")

	_phases.clear()
	melee.emit_signal("stage_started", &"hook", 3)
	_check(_phases.is_empty() \
			and slash.hook_emission_scale >= 0.80 \
			and slash.hook_emission_scale <= 0.84 \
			and absf(float(slash.call("_punch_emission_scale")) \
				- slash.punch_emission_scale * slash.hook_emission_scale) < 0.001,
		"hook shows no VFX before hit and applies its restrained broad-area glow")
	slash.call("_on_impact_landed", robber, first_impact_position)
	_check(slash.get_node_or_null(^"Stage3Lightning") == null \
			and slash.get_node_or_null(^"HookContactSprite") != null \
			and slash.get_node_or_null(^"HookContactSmoke") != null \
			and slash.get_node_or_null(^"HookContactVolume") != null \
			and slash.get_node_or_null(^"HookContactSurfaceCore") != null \
			and slash.get_node_or_null(^"HookContactSurfacePlasma") != null \
			and slash.get_node_or_null(^"HookContactSurfaceVolume") != null \
			and slash.get_node_or_null(^"HookContactHotCore") != null \
			and slash.get_node_or_null(^"HookContactPenetrationCore") != null \
			and slash.get_node_or_null(^"HookImpactCore") == null \
			and _phases.has(&"hook_contact_burst"),
		"left hook starts with the extracted attached contact sprite")
	var hook_contact := slash.get_node(^"HookContactSprite") as MeshInstance3D
	var hook_contact_smoke := slash.get_node(^"HookContactSmoke") \
		as MeshInstance3D
	var hook_surface_core := slash.get_node_or_null(^"HookContactSurfaceCore") \
		as MeshInstance3D
	var hook_surface_plasma := slash.get_node( \
		^"HookContactSurfacePlasma") as MeshInstance3D
	var hook_penetration := slash.get_node( \
		^"HookContactPenetrationCore") as MeshInstance3D
	var hook_contact_material := (hook_contact.mesh as QuadMesh).material \
		as BaseMaterial3D
	var hook_contact_smoke_material := \
		(hook_contact_smoke.mesh as QuadMesh).material as BaseMaterial3D
	var hook_metrics: Dictionary = slash.call("_target_effect_metrics", robber,
		first_impact_position)
	var hook_target_center: Vector3 = hook_metrics.center
	var hook_direction := robber.global_position - slash.global_position
	hook_direction.y = 0.0
	hook_direction = hook_direction.normalized()
	var expected_contact_core := hook_target_center \
		- Vector3.UP * float(hook_metrics.height) * slash.hook_contact_lower_ratio \
		+ hook_direction * float(hook_metrics.width) * 0.05
	var hook_camera_forward: Vector3 = slash.call("_camera_forward")
	var actual_contact_core: Vector3 = hook_contact.global_position \
		+ hook_direction * (slash.hook_contact_core_u - 0.5) \
		* slash.hook_contact_size.x \
		- hook_camera_forward * float(hook_metrics.width) \
		* slash.hook_depth_ratio
	var hook_surface_plasma_size := \
		(hook_surface_plasma.mesh as QuadMesh).size
	var hook_surface_plasma_core := hook_surface_plasma.global_position \
		+ hook_direction * (slash.hook_contact_core_u - 0.5) \
		* hook_surface_plasma_size.x
	var hook_penetration_size := (hook_penetration.mesh as QuadMesh).size
	var hook_penetration_anchor := hook_penetration.global_position \
		+ hook_direction * (slash.straight_trail_contact_u - 0.5) \
		* hook_penetration_size.x
	var expected_penetration_position := expected_contact_core \
		+ hook_direction * float(hook_metrics.width) * 0.02
	if hook_surface_core != null:
		var hook_surface_material := (hook_surface_core.mesh as QuadMesh).material \
			as BaseMaterial3D
		var hook_surface_core_size := (hook_surface_core.mesh as QuadMesh).size
		var hook_surface_core_anchor := hook_surface_core.global_position \
			+ hook_direction * (slash.straight_contact_core_u - 0.5) \
			* hook_surface_core_size.x
		_check(not hook_contact_material.no_depth_test \
				and hook_contact_material.blend_mode \
				== BaseMaterial3D.BLEND_MODE_ADD \
				and hook_contact_smoke_material.blend_mode \
				== BaseMaterial3D.BLEND_MODE_MIX \
				and hook_surface_material.no_depth_test \
				and hook_surface_core_anchor.distance_to(expected_contact_core) < 0.01 \
				and hook_surface_plasma_core.distance_to(expected_contact_core) < 0.01 \
				and hook_penetration_anchor.distance_to( \
					expected_penetration_position) < 0.01 \
				and hook_penetration_size.is_equal_approx(Vector2( \
					float(hook_metrics.width) * 1.35, \
					float(hook_metrics.height) * 0.14)) \
				and actual_contact_core.distance_to(expected_contact_core) < 0.01,
			"left hook anchors its depth-tested burst core inside the enemy and keeps only a small surface core")
	var hook_contact_size := (hook_contact.mesh as QuadMesh).size
	# 接触を胴の中心から大きく下げると腰より下に出て、どこに当たったか読めない。
	_check(hook_contact_size.x > hook_contact_size.y * 1.45 \
			and hook_target_center.y - expected_contact_core.y < 0.10,
		"left hook contact uses a wide asymmetric burst at the struck height")
	await get_tree().create_timer(slash.hook_follow_interval * 1.25).timeout
	_check(slash.get_node_or_null(^"HookFollowSprite") != null \
			and slash.get_node_or_null(^"HookFollowSmoke") != null \
			and slash.get_node_or_null(^"HookFollowVolume") != null \
			and slash.get_node_or_null(^"HookFollowSurfacePlasma") != null \
			and slash.get_node_or_null(^"HookFollowSurfaceVolume") != null \
			and slash.get_node_or_null(^"HookFollowHotCore") != null \
			and slash.get_node_or_null(^"HookFollowPenetrationCore") != null \
			and slash.get_node_or_null(^"HookFollowBodySprite") == null \
			and slash.get_node_or_null(^"HookFollowSurfaceCore") != null \
			and _phases.has(&"hook_follow_through"),
		"left hook advances to one broad low horizontal follow-through")
	var hook_follow := slash.get_node(^"HookFollowSprite") as MeshInstance3D
	var hook_follow_smoke := slash.get_node(^"HookFollowSmoke") \
		as MeshInstance3D
	var hook_follow_surface := slash.get_node(^"HookFollowSurfaceCore") \
		as MeshInstance3D
	var hook_follow_surface_plasma := slash.get_node( \
		^"HookFollowSurfacePlasma") as MeshInstance3D
	var hook_follow_penetration := slash.get_node( \
		^"HookFollowPenetrationCore") as MeshInstance3D
	var hook_follow_material := (hook_follow.mesh as QuadMesh).material \
		as BaseMaterial3D
	var hook_follow_smoke_material := \
		(hook_follow_smoke.mesh as QuadMesh).material as BaseMaterial3D
	var hook_follow_surface_material := (hook_follow_surface.mesh as QuadMesh).material \
		as BaseMaterial3D
	var expected_follow_core := hook_target_center \
		- Vector3.UP * float(hook_metrics.height) * slash.hook_follow_lower_ratio \
		+ hook_direction * float(hook_metrics.width) * 0.05
	var actual_follow_core: Vector3 = hook_follow.global_position \
		+ hook_direction * (slash.hook_follow_core_u - 0.5) \
		* slash.hook_follow_size.x \
		- hook_camera_forward * float(hook_metrics.width) \
		* slash.hook_depth_ratio
	var hook_follow_surface_plasma_size := \
		(hook_follow_surface_plasma.mesh as QuadMesh).size
	var hook_follow_surface_plasma_core := \
		hook_follow_surface_plasma.global_position \
		+ hook_direction * (slash.hook_follow_core_u - 0.5) \
		* hook_follow_surface_plasma_size.x
	var hook_follow_penetration_size := \
		(hook_follow_penetration.mesh as QuadMesh).size
	var hook_follow_surface_size := \
		(hook_follow_surface.mesh as QuadMesh).size
	var hook_follow_surface_anchor := hook_follow_surface.global_position \
		+ hook_direction * (slash.straight_contact_core_u - 0.5) \
		* hook_follow_surface_size.x
	var hook_follow_penetration_anchor := \
		hook_follow_penetration.global_position \
		+ hook_direction * (slash.straight_trail_contact_u - 0.5) \
		* hook_follow_penetration_size.x
	var expected_follow_penetration_position := expected_follow_core \
		+ hook_direction * float(hook_metrics.width) * 0.03
	_check(not hook_follow_material.no_depth_test \
			and hook_follow_material.blend_mode \
			== BaseMaterial3D.BLEND_MODE_ADD \
			and hook_follow_smoke_material.blend_mode \
			== BaseMaterial3D.BLEND_MODE_MIX \
			and hook_follow_surface_material.no_depth_test \
			and hook_follow_surface_anchor.distance_to(expected_follow_core) < 0.01 \
			and hook_follow_surface_plasma_core.distance_to( \
				expected_follow_core) < 0.01 \
			and hook_follow_penetration_anchor.distance_to( \
				expected_follow_penetration_position) < 0.01 \
			and hook_follow_penetration_size.is_equal_approx(Vector2( \
				float(hook_metrics.width) * 1.85, \
				float(hook_metrics.height) * 0.10)) \
			and actual_follow_core.distance_to(expected_follow_core) < 0.01 \
			and expected_follow_core.y <= expected_contact_core.y + 0.001,
		"left hook follow-through keeps its core inside the enemy and never rises above contact")
	_check_embers(slash, slash.finisher_ember_amount)

	_check_kick_mapping(melee, slash, robber, first_impact_position)
	_check(_spawned.size() == 6,
		"one effect event is emitted for each landed punch and kick")
	_check(_spawned.map(func(value: Dictionary) -> StringName:
		return value.technique) == [&"jab", &"straight", &"hook",
			&"knee", &"middle", &"high"],
		"effect events preserve the six landed technique identities")
	_check(_spawned[0].position.is_equal_approx(first_impact_position), "effect uses the hurtbox contact position")
	_check(_spawned[3].position.is_equal_approx(first_impact_position) \
			and _spawned[4].position.is_equal_approx(first_impact_position) \
			and _spawned[5].position.is_equal_approx(first_impact_position),
		"kick events keep the semantic hurtbox contact while their art follows the foot")
	_check(float(_spawned[0].position.y) > 0.5, "effect origin stays above the floor")
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(_failures)

func _land(hitbox: Hitbox, hurtbox: Hurtbox) -> void:
	hitbox.configure(1.0, 0.0, false)
	hitbox.call("_try_hit", hurtbox)

func _check_embers(slash: ImpactSlashType, amount: int) -> void:
	var particles: GPUParticles3D = null
	for child in slash.get_children():
		if child is GPUParticles3D:
			if (child as GPUParticles3D).amount == amount:
				particles = child as GPUParticles3D
				break
	_check(particles != null and particles.one_shot and particles.amount == amount, "hit creates the configured residual ember particles")
	if particles == null: return
	var process := particles.process_material as ParticleProcessMaterial
	var quad := particles.draw_pass_1 as QuadMesh
	var material := quad.material as StandardMaterial3D
	var streak_aspect := maxf(quad.size.x, quad.size.y) / minf(quad.size.x, quad.size.y)
	_check(process.particle_flag_align_y and streak_aspect > 4.0 and material.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "embers are velocity-aligned stretched particle billboards")

func _check_kick_mapping(melee: Node, slash: ImpactSlashType,
		target: Node3D, impact_position: Vector3) -> void:
	_phases.clear()
	melee.emit_signal("stage_started", &"knee", 7)
	_check(slash.kick_tracking_bone_name() == &"RightLowerLeg" \
			and int(slash.get("_kick_toe_bone")) < 0 \
			and is_equal_approx(slash.kick_toe_anchor_ratio, 0.90) \
			and slash.kick_sample_count() >= 1 \
			and slash.get_node_or_null(^"KickFootTrail") == null \
			and not _phases.has(&"kick_foot_trail"),
		"knee keeps the preferred striking-knee anchor and stays invisible before hit")
	slash.call("_on_impact_landed", target, impact_position)
	var knee_trail := slash.get_node_or_null(^"KickFootTrail") as Node3D
	_check_kick_trail(knee_trail, slash, 0.88, "knee")

	_phases.clear()
	melee.emit_signal("stage_started", &"middle", 5)
	_check(slash.kick_tracking_bone_name() == &"RightFoot" \
			and slash.get_node_or_null(^"KickFootTrail") == null \
			and _phases.is_empty(),
		"middle maps by technique to RightFoot and stays invisible before hit")
	slash.call("_on_impact_landed", target, impact_position)
	var middle_trail := slash.get_node_or_null(^"KickFootTrail") as Node3D
	_check_kick_trail(middle_trail, slash, 1.0, "middle")

	# Empty swings may retain a tiny hidden late-impact buffer, but must never
	# create a render node or phase. The following stage clears that buffer.
	_phases.clear()
	melee.emit_signal("stage_started", &"middle", 99)
	melee.emit_signal("combo_finished")
	_check(slash.get_node_or_null(^"KickFootTrail") == null \
			and _phases.is_empty(),
		"an empty kick combo finishes with zero visible VFX")
	melee.emit_signal("stage_started", &"jab", 1)
	_check(slash.kick_tracking_bone_name().is_empty() \
			and slash.kick_sample_count() == 0,
		"the next non-kick stage clears the hidden empty-swing history")

	# kick_3's combo-out and hitbox-close times straddle one physics tick. A
	# landed Area3D signal after combo_finished must still use the real history.
	_phases.clear()
	melee.emit_signal("stage_started", &"high", 2)
	var high_samples_before_finish := slash.kick_sample_count()
	melee.emit_signal("combo_finished")
	_check(slash.kick_tracking_bone_name() == &"RightFoot" \
			and slash.kick_sample_count() == high_samples_before_finish \
			and slash.get_node_or_null(^"KickFootTrail") == null,
		"high keeps its hidden foot history through a same-tick combo finish")
	slash.call("_on_impact_landed", target, impact_position)
	var high_trail := slash.get_node_or_null(^"KickFootTrail") as Node3D
	_check_kick_trail(high_trail, slash, 1.16, "high")

	# Sampling must accumulate slow sub-threshold movement instead of moving the
	# sole sample forward forever.
	melee.emit_signal("stage_started", &"jab", 1)
	slash.call("_reset_kick_tracking")
	slash.call("_append_kick_sample", Vector3.ZERO)
	slash.call("_append_kick_sample", Vector3(0.006, 0.0, 0.0))
	slash.call("_append_kick_sample", Vector3(0.012, 0.0, 0.0))
	slash.call("_append_kick_sample", Vector3(0.018, 0.0, 0.0))
	var accumulated_path: float = slash.call("_kick_path_length",
		slash.get("_kick_samples") as PackedVector3Array)
	_check(slash.kick_sample_count() >= 2 \
			and accumulated_path >= slash.kick_trail_min_sample_distance - 0.0001,
		"sub-threshold kick motion accumulates into a real history segment")
	slash.call("_reset_kick_tracking")


func _check_kick_trail(trail: Node3D, slash: ImpactSlashType,
		scale: float, label: String) -> void:
	_check(trail != null \
			and trail.get_node_or_null(^"KickTrailSmoke") != null \
			and trail.get_node_or_null(^"KickTrailAura") != null \
			and trail.get_node_or_null(^"KickTrailBandCore") != null \
			and trail.get_node_or_null(^"KickTrailBright") != null \
			and trail.get_node_or_null(^"KickTrailCore") != null \
			and trail.get_node_or_null(^"KickImpactPlumeSmoke") != null \
			and trail.get_node_or_null(^"KickImpactPlumeAura") != null \
			and trail.get_node_or_null(^"KickImpactPlumeBright") != null \
			and trail.get_node_or_null(^"KickImpactPlumeCore") != null \
			and trail.get_node_or_null(^"KickFootContact") != null \
			and trail.get_node_or_null(^"KickFootFlashHalo") != null \
			and trail.get_node_or_null(^"KickFootFlashCore") != null \
			and trail.get_node_or_null(^"KickContactCrescentHalo") == null \
			and trail.get_node_or_null(^"KickContactCrescent") == null \
			and trail.get_node_or_null(^"KickContactCrescentCore") == null \
			and trail.get_node_or_null(^"KickFootLight") != null \
			and _phases.has(&"kick_foot_trail") \
			and slash.get_node_or_null(^"ImpactBloom") == null \
			and slash.get_node_or_null(^"ImpactHotCore") == null \
			and slash.get_node_or_null(^"ImpactSmear") == null,
		label + " confirmed hit creates the layered trail without the removed fixed C-arc")
	if trail == null:
		return
	var endpoint := slash.kick_trail_endpoint()
	var expected_anchor: Vector3 = slash.call("_kick_anchor_position",
		endpoint)
	_check(endpoint.distance_to(expected_anchor) < 0.01,
		label + " white-hot endpoint starts on the live kick bone")

	var head := trail.get_node(^"KickFootContact") as MeshInstance3D
	var head_quad := head.mesh as QuadMesh
	var head_core := head.global_position \
		+ head.global_basis.x * (0.66 - 0.5) * head_quad.size.x
	var flash_core := trail.get_node(^"KickFootFlashCore") as MeshInstance3D
	var flash_quad := flash_core.mesh as QuadMesh
	var plume_core := trail.get_node(^"KickImpactPlumeCore") as MeshInstance3D
	var plume_quad := plume_core.mesh as QuadMesh
	var plume_hot_end := plume_core.global_position \
		+ plume_core.global_basis.x * (0.89 - 0.5) * plume_quad.size.x
	var expected_head_size := slash.kick_contact_size * scale * slash.kick_vfx_scale
	var expected_flash_size := Vector2(expected_head_size * 1.584,
		expected_head_size * 0.82) if label == "high" else Vector2(
			expected_head_size * 1.35, expected_head_size * 0.96)
	expected_flash_size.x *= 0.72 if label in ["middle", "high"] else 0.88
	expected_flash_size.y *= 0.84 if label == "middle" else ( \
		0.72 if label == "high" else 0.88)
	expected_flash_size.y *= 1.18
	_check(head_core.distance_to(endpoint) < 0.02 \
			and flash_core.global_position.distance_to(endpoint) < 0.01 \
			and plume_hot_end.distance_to(endpoint) < 0.02 \
			and flash_quad.size.is_equal_approx(expected_flash_size),
		label + " anchors the dense rear plume, texture core, and white flare to the live strike point")

	var band := trail.get_node(^"KickTrailBandCore") as MeshInstance3D
	var band_mesh := band.mesh as ArrayMesh
	var white_wedge := trail.get_node(^"KickTrailBright") as MeshInstance3D
	var white_wedge_mesh := white_wedge.mesh as ArrayMesh
	var geometry_ok := band_mesh != null and band_mesh.get_surface_count() == 1
	var side_basis_ok := geometry_ok
	var endpoint_ok := geometry_ok
	var horizontal_shape_ok := geometry_ok
	if geometry_ok:
		var arrays := band_mesh.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var previous_width := Vector3.ZERO
		var first_center := Vector3.ZERO
		var last_center := Vector3.ZERO
		var camera_forward: Vector3 = slash.call("_camera_forward")
		for index: int in range(0, vertices.size(), 2):
			var width_vector := vertices[index] - vertices[index + 1]
			var center := (vertices[index] + vertices[index + 1]) * 0.5
			if index == 0:
				first_center = center
			last_center = center
			side_basis_ok = side_basis_ok \
				and absf(width_vector.normalized().dot(camera_forward)) < 0.001
			if previous_width.length_squared() > 0.0:
				side_basis_ok = side_basis_ok \
					and width_vector.dot(previous_width) >= -0.000001
			previous_width = width_vector
		endpoint_ok = last_center.distance_to(endpoint) < 0.01
		var travel := last_center - first_center
		var horizontal := Vector2(travel.x, travel.z).length()
		if label == "high":
			var strike_axis: Vector3 = trail.get("_strike_axis")
			strike_axis -= camera_forward * strike_axis.dot(camera_forward)
			horizontal_shape_ok = strike_axis.length_squared() > 0.000001 \
				and absf(travel.normalized().dot(strike_axis.normalized())) > 0.92
		else:
			horizontal_shape_ok = horizontal > absf(travel.y) * 1.6
	_check(geometry_ok and side_basis_ok and endpoint_ok,
		label + " ribbon is camera-facing, untwisted, and ends at the live strike point")
	_check(horizontal_shape_ok,
		label + (" open band follows the live knee-to-foot axis" if label == "high" \
		else " contact ribbon keeps the requested side-view horizontal silhouette"))
	_check(slash.kick_vfx_scale >= 1.15,
		label + " applies the requested larger overall kick VFX scale")
	_check((label != "high" and float(trail.get("_base_light_energy")) > 0.0) \
			or (label == "high" and is_zero_approx(
				float(trail.get("_base_light_energy")))),
		label + " suppresses real lighting only for the floor-crossing high return")
	var finisher_outline := trail.get_node(^"KickTrailLightningOuter") \
		as MeshInstance3D
	if label == "high":
		var outline_aabb := (finisher_outline.mesh as ArrayMesh).get_aabb()
		var branch_outline := trail.get_node_or_null(
			^"KickTrailLightningBranchOuter") as MeshInstance3D
		var branch_aabb := (branch_outline.mesh as ArrayMesh).get_aabb() \
			if branch_outline != null else AABB()
		var combined_outline_aabb := outline_aabb.merge(branch_aabb)
		var band_aabb := band_mesh.get_aabb()
		var band_length := band_aabb.size.length()
		_check(bool(trail.get("_finisher")) \
				and branch_outline != null \
				and combined_outline_aabb.size.length() > expected_head_size * 2.75 \
				and band_length > expected_head_size * 2.90 \
				and white_wedge_mesh != null,
			"high keeps a compact leg-aligned frame and an open textured band without a fixed C")

	var band_material := band.material_override as ShaderMaterial
	var head_material := head.material_override as ShaderMaterial
	var flash_material := flash_core.material_override as ShaderMaterial
	_check(float(band_material.get_shader_parameter("emission_energy")) >= 3.4 \
			and float(band_material.get_shader_parameter("emission_energy")) <= 4.3 \
			and float(head_material.get_shader_parameter("emission_energy")) \
				>= (5.3 if label == "high" else 4.7) \
			and float(head_material.get_shader_parameter("emission_energy")) \
				<= (5.5 if label == "high" else 4.9) \
			and float(flash_material.get_shader_parameter("emission_energy")) \
				>= (6.7 if label == "high" else 5.7) \
			and float(flash_material.get_shader_parameter("emission_energy")) \
				<= (6.9 if label == "high" else 5.9),
		label + " uses the restrained punch brightness hierarchy at the kick contact core")

	var fade_in := float(trail.get("_fade_in_duration"))
	var duration := float(trail.get("_duration"))
	var fade_out := float(trail.get("_fade_out_duration"))
	var contact_duration := float(trail.get("_contact_duration"))
	var fade_mid := float(trail.call("_opacity_at", fade_in * 0.5))
	var late_sample := 0.14
	var trail_late := float(trail.call("_opacity_at", late_sample))
	var contact_late := float(trail.call("_contact_opacity_at", late_sample))
	var trail_first_frame := float(trail.call("_opacity_at", 0.016))
	var trail_second_frame := float(trail.call("_opacity_at", 0.033))
	var contact_first_frame := float(trail.call("_contact_opacity_at", 0.016))
	var fade_timing_ok := fade_in >= 0.025 and fade_in <= 0.027 \
			and trail_first_frame > 0.60 and trail_first_frame < 0.75 \
			and trail_second_frame > 0.99 \
			and contact_first_frame > 0.85 and contact_first_frame < 0.95 \
		if label == "high" else fade_in >= 0.044 and fade_in <= 0.046 \
			and trail_first_frame > 0.20 and trail_first_frame < 0.34 \
			and trail_second_frame > 0.68 and trail_second_frame < 0.86 \
			and contact_first_frame > trail_first_frame \
			and contact_first_frame < 0.60
	_check(is_zero_approx(float(trail.call("_opacity_at", 0.0))) \
			and fade_timing_ok \
			and fade_mid > 0.0 and fade_mid < 1.0 \
			and is_equal_approx(float(trail.call("_opacity_at", fade_in)), 1.0) \
			and is_equal_approx(float(trail.call("_opacity_at",
				duration - fade_out)), 1.0) \
			and is_zero_approx(float(trail.call("_opacity_at", duration))) \
			and contact_late < trail_late,
		label + " visibly fades in over multiple frames and lets the white core die first")
	if label == "high":
		var outline_early := float(trail.call(
			"_finisher_outline_opacity_at", 0.016))
		var band_late := float(trail.call(
			"_finisher_band_opacity_at", 0.16))
		var outline_followthrough := float(trail.call(
			"_finisher_outline_opacity_at", 0.12))
		var band_followthrough := float(trail.call(
			"_finisher_band_opacity_at", 0.12))
		var outline_core_peak := float(trail.call(
			"_finisher_outline_core_opacity_at", 0.045))
		var outline_core_followthrough := float(trail.call(
			"_finisher_outline_core_opacity_at", 0.12))
		_check(duration >= 0.175 and duration <= 0.185 \
				and contact_duration >= 0.085 and contact_duration <= 0.095 \
				and float(trail.get("_light_duration")) <= 0.11 \
				and is_zero_approx(float(slash.get("_kick_follow_time_left"))) \
				and outline_early > 0.50 and outline_early < 0.65 \
				and outline_followthrough > 0.20 \
				and outline_followthrough < 0.35 \
				and band_followthrough < 0.10 \
				and is_equal_approx(outline_core_peak, 1.0) \
				and outline_core_followthrough < 0.01 \
				and band_late < 0.01,
			"high eases in and fully clears its frame inside the same brief kick window")

	var moved_endpoint := endpoint + Vector3(0.025, 0.035, 0.0)
	var outline_center_before := _mesh_vertex_centroid(
		finisher_outline.mesh as ArrayMesh)
	trail.call("follow_endpoint", moved_endpoint)
	var moved_head_core := head.global_position \
		+ head.global_basis.x * (0.66 - 0.5) * head_quad.size.x
	var outline_center_after := _mesh_vertex_centroid(
		finisher_outline.mesh as ArrayMesh)
	var outline_locked_ok := outline_center_after.distance_to(
		outline_center_before) < 0.001 if label == "high" else true
	var locked_band_endpoint_ok := true
	if label == "high":
		var moved_band_mesh := band.mesh as ArrayMesh
		var moved_arrays := moved_band_mesh.surface_get_arrays(0)
		var moved_vertices := moved_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var last_index := moved_vertices.size() - 2
		var moved_band_center := (moved_vertices[last_index] \
			+ moved_vertices[last_index + 1]) * 0.5
		locked_band_endpoint_ok = moved_band_center.distance_to(endpoint) < 0.01 \
			and moved_band_mesh == band_mesh
	_check(slash.kick_trail_endpoint().distance_to(endpoint) < 0.001 \
			and moved_head_core.distance_to(endpoint) < 0.02 \
			and outline_locked_ok \
			and locked_band_endpoint_ok,
		label + " locks the impact in world space while the striking leg recovers")
	slash.call("_spawn_kick_hit", moved_endpoint, Vector3.RIGHT)
	var trail_count := 0
	for child: Node in slash.get_children():
		if child.name == &"KickFootTrail":
			trail_count += 1
	_check(trail_count == 1,
		label + " reuses one foot trail for additional targets in the same kick")


func _mesh_vertex_centroid(mesh: ArrayMesh) -> Vector3:
	if mesh == null or mesh.get_surface_count() == 0:
		return Vector3.INF
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if vertices.is_empty():
		return Vector3.INF
	var center := Vector3.ZERO
	for vertex: Vector3 in vertices:
		center += vertex
	return center / float(vertices.size())


func _has_damage_label(node: Node) -> bool:
	for child in node.get_children():
		if child is Label3D or _has_damage_label(child):
			return true
	return false


func _has_legacy_damage_burst(node: Node) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D or child is GPUParticles3D \
				or _has_legacy_damage_burst(child):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
