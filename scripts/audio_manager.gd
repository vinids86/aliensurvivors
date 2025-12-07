extends Node

# Configuração do Pool
const POOL_SIZE = 32 # Quantos sons simultâneos podem tocar (ajuste conforme necessário)
const BUS_NAME = "SFX"

# Array para armazenar os players reutilizáveis
var _pool_2d: Array[AudioStreamPlayer2D] = []

func _ready() -> void:
	# Cria os players antecipadamente (Ao iniciar o jogo)
	# Isso move o custo de processamento para a tela de load, eliminando lag durante o gameplay
	for i in POOL_SIZE:
		var player = AudioStreamPlayer2D.new()
		player.bus = BUS_NAME
		player.max_distance = 2000 # Ajuste conforme o zoom da sua câmera
		
		# Otimização: Desativa processamento quando não está tocando
		player.finished.connect(func(): player.process_mode = Node.PROCESS_MODE_DISABLED)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		
		add_child(player)
		_pool_2d.append(player)

## Toca um som 2D em uma posição específica usando um player da piscina.
## Retorna o player usado ou null se todos estiverem ocupados.
func play_sfx_2d(stream: AudioStream, global_pos: Vector2, pitch_range: float = 0.1, volume_db: float = 0.0) -> void:
	if not stream: return

	var player = _get_available_player()
	
	if not player:
		# Pool cheia! 
		# Em Survivors, é melhor ignorar sons extras do que baixar o FPS instanciando novos.
		# (Opcional: Você poderia implementar lógica para roubar o player mais antigo)
		return 
	
	# Reativa e configura
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = global_pos
	player.stream = stream
	player.volume_db = volume_db
	
	# Variação de Pitch para evitar efeito "metralhadora robótica"
	if pitch_range > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	else:
		player.pitch_scale = 1.0
		
	player.play()

func _get_available_player() -> AudioStreamPlayer2D:
	for player in _pool_2d:
		if not player.playing:
			return player
	return null
