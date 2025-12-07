shader_type canvas_item;

// --- Configurações Visuais ---
uniform vec4 base_color : source_color = vec4(1.0, 0.3, 0.1, 1.0); // Laranja Neon
uniform vec4 core_color : source_color = vec4(0.2, 0.0, 0.05, 1.0); // Núcleo escuro
uniform vec4 flash_color : source_color = vec4(1.0, 0.9, 0.8, 1.0); // Branco quente

// --- Variáveis de Controle ---
uniform float charge_level : hint_range(0.0, 1.0) = 0.0; 
uniform float shake_power : hint_range(0.0, 50.0) = 0.0; 

// --- Funções Matemáticas ---

vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Ruído simples para erosão
float erosion_noise(vec2 uv, float time) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    
    float a = random2(i).x;
    float b = random2(i + vec2(1.0, 0.0)).x;
    float c = random2(i + vec2(0.0, 1.0)).x;
    float d = random2(i + vec2(1.0, 1.0)).x;

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

float crystal_volumes(vec2 uv, float time) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float min_dist = 1.0;
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = random2(i + neighbor);
            
            float anim_speed = 1.0 + (charge_level * 5.0);
            point = 0.5 + 0.5 * sin(time * anim_speed + 6.2831 * point);
            
            vec2 diff = neighbor + point - f;
            float dist = length(diff);
            
            min_dist = min(min_dist, dist);
        }
    }
    return min_dist;
}

void vertex() {
    // Como estamos usando ColorRect (apenas 4 vértices),
    // Vertex displacement não funciona bem para deformar a forma.
    // Movemos a lógica de tremor para o fragment shader.
}

void fragment() {
    vec2 uv = UV;
    
    // --- 0. TREMOR E GLITCH (Substituindo Vertex Displacement) ---
    // Distorce o UV inteiro baseado no shake_power para simular o tremor
    if (shake_power > 0.0) {
        float snap_rate = 20.0;
        float time_step = floor(TIME * snap_rate);
        vec2 shake_offset = (random2(vec2(time_step, uv.y)) - 0.5) * 0.1; // 0.1 = amplitude
        
        // Aplica o shake
        uv += shake_offset * (shake_power * 0.01) * (0.5 + 0.5 * charge_level);
    }

    vec2 centered_uv = uv - 0.5;

    // --- 1. MÁSCARA DE FORMA (Ajustada para encher o Retângulo) ---
    // AJUSTE CRÍTICO: Aumentei os multiplicadores para encolher a forma visualmente
    // (Quanto maior o número aqui, mais rápido chegamos na borda, logo menor a forma)
    // 1.5 e 1.2 garantem que as pontas terminem ANTES de bater na borda do ColorRect.
    
    // Forma base: Um losango esticado verticalmente (Pipa)
    float diamond_dist = abs(centered_uv.x * 1.5) + abs(centered_uv.y * 1.2);
    
    // Adiciona ruído à borda
    float edge_noise_val = erosion_noise(uv * 8.0 + vec2(0, TIME), TIME);
    
    // O shape mask define a distância. Quanto menor o diamond_dist, mais perto do centro.
    float shape_mask = diamond_dist - (edge_noise_val * 0.1);
    
    // CORTE ALPHA: Aumentei o threshold para 0.45-0.5.
    // Isso significa que pixels mais longe do centro agora serão visíveis.
    float alpha = 1.0 - smoothstep(0.45, 0.50, shape_mask);

    // --- 2. PADRÃO INTERNO ---
    float distorcao = charge_level * 0.1;
    vec2 distorted_uv = uv + vec2(random2(uv + TIME).x - 0.5) * distorcao;

    float noise_val = crystal_volumes(distorted_uv * 3.0, TIME); // *3.0 para cristais maiores
    float energy_blob = smoothstep(0.2, 0.8, 1.0 - noise_val);
    
    // --- 3. COR ---
    vec3 final_color = mix(core_color.rgb, base_color.rgb, energy_blob * 0.8);
    
    float hotspots = smoothstep(0.7, 1.0, energy_blob);
    final_color += base_color.rgb * hotspots * (1.0 + charge_level * 3.0);

    // --- 4. BORDAS ---
    // Ajustado para seguir a nova máscara
    float rim = smoothstep(0.50, 0.45, shape_mask) * smoothstep(0.35, 0.45, shape_mask);
    final_color += base_color.rgb * rim * 2.0;

    // --- 5. FLASH ---
    float flash = smoothstep(0.7, 1.0, charge_level) * (sin(TIME * 50.0) * 0.5 + 0.5);
    final_color = mix(final_color, flash_color.rgb, flash); 

    COLOR = vec4(final_color, alpha);
}