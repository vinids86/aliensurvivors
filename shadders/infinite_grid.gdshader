shader_type canvas_item;

// Cores do Fundo (Deep Space Water)
uniform vec4 color_deep : source_color = vec4(0.02, 0.02, 0.1, 1.0); 
uniform vec4 color_shallow : source_color = vec4(0.0, 0.2, 0.5, 1.0); 
uniform vec4 color_foam : source_color = vec4(0.1, 0.4, 0.6, 1.0); 

// Configuração do Movimento
uniform float time_scale = 0.5;
uniform float distortion_strength = 0.05; 

// ESCALA DO GRID (Tile)
// Quanto maior, mais células. Deve ser inteiro para facilitar o tiling.
uniform float tile_scale = 4.0; 

vec2 hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float voronoi(vec2 uv, float time) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float min_dist = 1.0;
	
	// Vizinhos
	for(int y = -1; y <= 1; y++) {
		for(int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			
			// --- CORREÇÃO DE TILING ---
			// A mágica acontece aqui: usamos MODULO para fazer o wrap around.
			// Se o vizinho for -1 (fora do grid), ele vira 'tile_scale - 1'.
			// Se for tile_scale (fora do grid), vira 0.
			vec2 tiled_pos = mod(i + neighbor, tile_scale);
			
			vec2 point = hash(tiled_pos);
			point = 0.5 + 0.5 * sin(time + 6.2831 * point);
			
			vec2 diff = neighbor + point - f;
			float dist = length(diff);
			min_dist = min(min_dist, dist);
		}
	}
	return min_dist;
}

void fragment() {
	// Normaliza UV para garantir distorção cíclica
	vec2 base_uv = UV;
	
	// 1. Distorção Cíclica (Seamless)
	// Usamos TAU (6.28) para garantir que sin(0) == sin(1), eliminando a costura na distorção.
	float angle_x = base_uv.y * 6.283185; 
	float angle_y = base_uv.x * 6.283185;
	
	vec2 offset;
	offset.x = sin(angle_x + TIME * time_scale) * distortion_strength;
	offset.y = cos(angle_y + TIME * time_scale * 0.8) * distortion_strength;
	
	// 2. Aplica escala APÓS a distorção baseada em 0..1
	// Isso garante que o UV final distorcido ainda respeite o tiling macro
	vec2 tiled_uv = (base_uv + offset) * tile_scale;

	// 3. Voronoi Tileable
	float v1 = voronoi(tiled_uv, TIME * time_scale);
	float v2 = voronoi(tiled_uv + vec2(2.3, 1.5), TIME * time_scale * 1.5);
	
	float fluid = v1 * v2; 
	fluid = smoothstep(0.0, 0.6, fluid);
	
	vec4 final_color = mix(color_deep, color_shallow, smoothstep(0.0, 0.4, fluid));
	final_color = mix(final_color, color_foam, smoothstep(0.4, 0.8, fluid) * 0.5);
	
	COLOR = final_color;
}