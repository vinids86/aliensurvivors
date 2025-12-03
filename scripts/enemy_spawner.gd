class_name EnemySpawner extends Node2D

## Gerenciador de Inimigos Orbital.
## Spawna inimigos em um anel ao redor do Player, garantindo que nasçam fora da tela.

# --- CONFIGURAÇÃO ---
@export_group("Spawn Settings")
@export var enemy_scene: PackedScene      # Arraste o basic_enemy.tscn aqui
@export var spawn_radius: float = 1000.0  # Distância do player (900 é seguro para 1080p)
@export var spawn_interval: float = 1.0   # Tempo entre inimigos (segundos)

@export_group("Difficulty Ramp")
@export var decrease_interval_per_spawn: float = 0.005 # Acelera 5ms a cada inimigo
@export var min_spawn_interval: float = 0.1            # Limite de velocidade (Machine Gun)

# --- REFERÊNCIAS ---
@export_group("References")
@export var player_ref: Node2D            # Arraste o Player aqui
@export var enemies_container: Node2D     # Arraste o "EnemiesContainer" aqui (Organização)

# Estado Interno
var _current_interval: float
var _timer: Timer

func _ready() -> void:
	# Validação
	if not enemy_scene:
		push_error("EnemySpawner: Nenhuma cena de inimigo configurada!")
		set_process(false)
		return
	
	_current_interval = spawn_interval
	
	# Cria o Timer via código para controle preciso da curva de dificuldade
	_timer = Timer.new()
	_timer.wait_time = _current_interval
	_timer.one_shot = false
	_timer.autostart = true
	_timer.timeout.connect(_spawn_enemy)
	add_child(_timer)

func _spawn_enemy() -> void:
	if not player_ref:
		# Tenta encontrar o player se a referência foi perdida ou não atribuída
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]
		else:
			return # Sem player, sem spawn

	# 1. Matemática Orbital
	# Escolhe um ângulo aleatório (0 a 360 graus em radianos)
	var angle = randf() * TAU
	# Calcula a posição baseada no seno/cosseno
	var spawn_pos = player_ref.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius
	
	# 2. Instancia
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	
	# 3. Adiciona à Cena (No Container correto para não sujar o World)
	if enemies_container:
		enemies_container.add_child(enemy)
	else:
		get_tree().root.add_child(enemy)
	
	# 4. Aumenta a Dificuldade (Rampa Linear Simples)
	if _current_interval > min_spawn_interval:
		_current_interval = max(min_spawn_interval, _current_interval - decrease_interval_per_spawn)
		_timer.wait_time = _current_interval

# Função Debug para visualizar o raio de spawn no editor
func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, spawn_radius, 0, TAU, 32, Color(1, 0, 0, 0.5), 2.0)
