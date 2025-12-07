extends CharacterBody2D

enum State { CHASE, PREPARE, DASH, RECOVERY }

# --- Configurações de Gameplay ---
@export_group("Attributes")
@export var normal_speed: float = 90.0
@export var dash_speed: float = 600.0
@export var damage: int = 15
@export var hp: int = 30

@export_group("Drops")
@export var xp_gem_scene: PackedScene
@export var xp_amount: int = 10

@export_group("Audio")
@export var sfx_hit: AudioStream
@export var sfx_charge: AudioStream
@export var sfx_dash: AudioStream
@export var sfx_death: AudioStream

@export_group("Timings")
@export var attack_range: float = 200.0
@export var prepare_time: float = 0.8
@export var dash_duration: float = 0.25
@export var recovery_time: float = 1.0

# --- Referências ---
@onready var visual_body: ColorRect = $ColorRect 
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trail_particles: GPUParticles2D = $TrailParticles 

var player: Node2D
var current_state: State = State.CHASE
var dash_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0

# FÍSICA AVANÇADA (Anti-Stick)
var _knockback_velocity: Vector2 = Vector2.ZERO
var _dash_residual: Vector2 = Vector2.ZERO # Preserva o deslize do dash separado do knockback

# Material do Shader
var shader_mat: ShaderMaterial

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	if trail_particles:
		_setup_particles()
	
	visual_body.pivot_offset = visual_body.size / 2.0
	
	if visual_body.material:
		visual_body.material = visual_body.material.duplicate()
		shader_mat = visual_body.material as ShaderMaterial

func _physics_process(delta: float) -> void:
	# Decaimento do Knockback (Independente do Estado)
	if _knockback_velocity.length_squared() > 10.0:
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		_knockback_velocity = Vector2.ZERO
		
	if not is_instance_valid(player): return
	
	match current_state:
		State.CHASE: _process_chase(delta)
		State.PREPARE: _process_prepare(delta)
		State.DASH: _process_dash(delta)
		State.RECOVERY: _process_recovery(delta)
	
	move_and_slide()
	_handle_collision_damage()

# --- Estados ---

func _process_chase(delta: float) -> void:
	var dist = global_position.distance_to(player.global_position)
	
	# Animação
	var t = Time.get_ticks_msec() * 0.005
	visual_body.scale = visual_body.scale.lerp(Vector2(1.0 - sin(t)*0.1, 1.0 + sin(t)*0.2), delta * 10.0)
	
	# LÓGICA ANTI-STICK:
	# Se estiver sob knockback forte, perde o controle de direção (steering)
	# Isso permite que o empurrão afaste o inimigo do player antes que ele volte a grudar.
	var is_taking_knockback = _knockback_velocity.length() > 50.0
	var control_factor = 0.05 if is_taking_knockback else 1.0
	
	var desired_velocity = Vector2.ZERO
	if dist > attack_range:
		desired_velocity = global_position.direction_to(player.global_position) * normal_speed
	else:
		_change_state(State.PREPARE) # Freia natural na transição
		return
		
	# Combina movimento voluntário (controlado) + Força Externa (Knockback)
	velocity = (desired_velocity * control_factor) + _knockback_velocity
	
	_rotate_visual(player.global_position, delta * 5.0)

func _process_prepare(delta: float) -> void:
	# Durante prepare, ele não anda, mas ainda sofre knockback
	velocity = _knockback_velocity
	
	var lock_speed = 5.0 * (state_timer / prepare_time)
	_rotate_visual(player.global_position, delta * lock_speed)
	
	state_timer -= delta
	if state_timer <= 0: _start_dash()

func _process_dash(delta: float) -> void:
	# Dash ignora knockback (imparável)
	velocity = dash_direction * dash_speed
	state_timer -= delta
	if state_timer <= 0: _change_state(State.RECOVERY)

func _process_recovery(delta: float) -> void:
	# Decai o deslize do Dash
	_dash_residual = _dash_residual.move_toward(Vector2.ZERO, 2000 * delta)
	
	# Soma o deslize do dash (se houver) + knockback (se levou tiro)
	velocity = _dash_residual + _knockback_velocity
	
	state_timer -= delta
	if state_timer <= 0: _change_state(State.CHASE)

# --- Sistema de Dano e Morte ---

func take_damage(amount: int, knockback_force: Vector2 = Vector2.ZERO) -> void:
	hp -= amount
	_play_sfx(sfx_hit)
	
	_flash_visual()
	
	if current_state != State.DASH:
		_apply_hit_squash()
		# ALTERAÇÃO: Aplica na variável separada, não na velocity direta
		_knockback_velocity = knockback_force
	
	if hp <= 0: die()

func die() -> void:
	_spawn_death_effect()
	_play_sfx(sfx_death)

	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate()
		gem.global_position = global_position
		if "amount" in gem: gem.amount = xp_amount
		elif "xp_amount" in gem: gem.xp_amount = xp_amount
		get_parent().call_deferred("add_child", gem)
	
	queue_free()

# --- Auxiliares ---

func _change_state(new_state: State) -> void:
	# Transição especial: Se veio do Dash para Recovery, guarda o momento
	if current_state == State.DASH and new_state == State.RECOVERY:
		_dash_residual = velocity
	else:
		_dash_residual = Vector2.ZERO
		
	current_state = new_state
	match new_state:
		State.PREPARE:
			state_timer = prepare_time
			_play_sfx(sfx_charge)
			_animate_shader(true)
			_tween_scale(Vector2(0.5, 1.5), prepare_time, Tween.TRANS_BACK, Tween.EASE_IN)
		State.RECOVERY:
			state_timer = recovery_time
			_animate_shader(false)
			if trail_particles: trail_particles.emitting = false
			_tween_scale(Vector2.ONE, 0.6, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
		State.CHASE:
			if shader_mat:
				shader_mat.set_shader_parameter("shake_power", 0.0)
				shader_mat.set_shader_parameter("charge_level", 0.0)

func _start_dash() -> void:
	current_state = State.DASH
	state_timer = dash_duration
	dash_direction = Vector2.RIGHT.rotated(visual_body.rotation)
	_play_sfx(sfx_dash)
	if trail_particles: trail_particles.emitting = true
	_tween_scale(Vector2(2.5, 0.4), 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT)

func _handle_collision_damage() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			if current_state == State.DASH:
				if collider.has_method("take_damage"):
					collider.take_damage(damage, self, 500.0)
					
					_change_state(State.RECOVERY)
					# Aplica o recuo na variável separada
					_knockback_velocity = -dash_direction * 600.0
					_dash_residual = Vector2.ZERO # Cancela o deslize do dash pois bateu

# --- Helpers Visuais/Audio ---

func _play_sfx(stream: AudioStream) -> void:
	if stream and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_2d(stream, global_position)

func _spawn_death_effect() -> void:
	var explosion = GPUParticles2D.new()
	explosion.emitting = false
	explosion.amount = 25
	explosion.lifetime = 0.6
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	explosion.global_position = global_position
	
	var mat = ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.spread = 180.0
	mat.initial_velocity_min = 150.0
	mat.initial_velocity_max = 300.0
	mat.damping_min = 100.0
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	
	var grad = Gradient.new()
	grad.colors = [Color(1.0, 0.4, 0.1, 1.0), Color(1.0, 0.1, 0.0, 0.0)]
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	explosion.process_material = mat
	
	var tex = GradientTexture2D.new()
	tex.width = 16; tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(0.5, 0.0)
	var tgrad = Gradient.new()
	tgrad.set_color(0, Color.WHITE); tgrad.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = tgrad
	explosion.texture = tex
	
	get_parent().call_deferred("add_child", explosion)
	explosion.finished.connect(explosion.queue_free)
	explosion.call_deferred("set_emitting", true)

func _setup_particles() -> void:
	trail_particles.emitting = false
	trail_particles.amount = 30
	trail_particles.local_coords = false
	trail_particles.lifetime = 0.5
	
	if not trail_particles.texture:
		var tex = GradientTexture2D.new()
		tex.width = 64; tex.height = 64
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(0.5, 0.0)
		var grad = Gradient.new()
		grad.set_color(0, Color.WHITE); grad.set_color(1, Color(1, 1, 1, 0))
		tex.gradient = grad
		trail_particles.texture = tex
	
	var mat = trail_particles.process_material as ParticleProcessMaterial
	if not mat:
		mat = ParticleProcessMaterial.new()
		trail_particles.process_material = mat
	
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(1, 0))
	var curve_tex = CurveTexture.new(); curve_tex.curve = curve
	mat.scale_curve = curve_tex
	
	var color_grad = Gradient.new()
	color_grad.set_color(0, Color(1.0, 0.4, 0.1, 1.0))
	color_grad.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	var color_ramp_tex = GradientTexture1D.new(); color_ramp_tex.gradient = color_grad
	mat.color_ramp = color_ramp_tex

func _rotate_visual(target_pos: Vector2, speed: float) -> void:
	var angle = global_position.angle_to_point(target_pos)
	visual_body.rotation = lerp_angle(visual_body.rotation, angle, speed)

func _animate_shader(is_charging: bool) -> void:
	if not shader_mat: return
	var tween = create_tween()
	if is_charging:
		tween.parallel().tween_property(shader_mat, "shader_parameter/charge_level", 1.0, prepare_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(shader_mat, "shader_parameter/shake_power", 30.0, prepare_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.parallel().tween_property(shader_mat, "shader_parameter/charge_level", 0.0, 0.5)
		tween.parallel().tween_property(shader_mat, "shader_parameter/shake_power", 0.0, 0.5)

func _flash_visual() -> void:
	var tween = create_tween()
	tween.tween_property(visual_body, "modulate", Color(2.0, 2.0, 2.0), 0.05)
	tween.tween_property(visual_body, "modulate", Color.WHITE, 0.05)

func _apply_hit_squash() -> void:
	var scale_tween = create_tween()
	scale_tween.tween_property(visual_body, "scale", Vector2(1.2, 0.8), 0.05).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(visual_body, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _tween_scale(target: Vector2, duration: float, trans: int, ease_type: int) -> void:
	var tween = create_tween()
	tween.tween_property(visual_body, "scale", target, duration).set_trans(trans).set_ease(ease_type)
