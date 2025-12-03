class_name AmbientDust extends CPUParticles2D

## Sistema de partículas ambientais: Céu Estrelado.
## Gera estrelas estáticas no mundo que variam em brilho e tamanho, criando paralaxe natural.
## O emissor segue a câmera, mas as partículas ficam fixas no espaço (local_coords = false).

func _ready() -> void:
	_configure_emission_area()
	_setup_star_visuals()

func _configure_emission_area() -> void:
	# Pega o tamanho da tela atual
	var viewport_size = get_viewport_rect().size
	
	# Define a área de emissão (Rectangle) baseada na tela com uma margem extra
	emission_rect_extents = viewport_size * 0.6
	
	# Garante que a tela já comece cheia de estrelas
	preprocess = lifetime

func _setup_star_visuals() -> void:
	# 1. Configuração Básica
	amount = 100            # Mais denso para um céu estrelado
	lifetime = 2.0          # Duram bastante tempo
	local_coords = false    # CRÍTICO: Elas ficam no mundo enquanto você passa
	
	# --- NOVO: GERAÇÃO DE TEXTURA PROCEDURAL (GLOW) ---
	# Cria uma textura 16x16 com um gradiente radial (bola suave)
	var glow_tex = GradientTexture2D.new()
	glow_tex.width = 16
	glow_tex.height = 16
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5) # Centro
	glow_tex.fill_to = Vector2(0.5, 0.0)   # Borda (Raio)
	
	var tex_gradient = Gradient.new()
	# Branco sólido no centro -> Transparente na borda
	tex_gradient.colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	glow_tex.gradient = tex_gradient
	
	texture = glow_tex
	# --------------------------------------------------
	
	# 2. Física (Estático)
	gravity = Vector2.ZERO
	direction = Vector2.ZERO
	spread = 0.0
	initial_velocity_min = 0.0
	initial_velocity_max = 0.0
	
	# 3. Tamanho e "Claridade"
	# Mantendo a escala ajustada para a textura de 16px
	scale_amount_min = 0.05
	scale_amount_max = 1.0
	
	# 4. Fade In / Fade Out (Cintilação Suave)
	var lifecycle_gradient = Gradient.new()
	lifecycle_gradient.offsets = [0.0, 0.15, 0.85, 1.0]
	lifecycle_gradient.colors = [
		Color(1, 1, 1, 0),   # Nasce Invisível
		Color(1, 1, 1, 1),   # Brilho Máximo
		Color(1, 1, 1, 1),   # Mantém
		Color(1, 1, 1, 0)    # Apaga
	]
	
	color_ramp = lifecycle_gradient
	
	# 5. Cor Base (Ajustada para Verde/Ciano Energético)
	# Combina com o shader de água e com a estética geométrica
	color = Color(0.2, 0.9, 0.8, 1.0)
