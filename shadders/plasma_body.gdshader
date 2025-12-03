shader_type canvas_item;

uniform vec4 base_color : source_color;
// Substituímos 'agitation' e 'TIME' por um tempo controlado manualmente pelo script
uniform float custom_time = 0.0; 

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	float dist = distance(uv, center);
	
	// Efeito: Plasma Fervendo (Restaurado com custom_time)
	// Mantivemos a matemática original visual, só trocando a fonte de tempo
	float plasma1 = sin(uv.x * 12.0 + custom_time * 3.0 + uv.y * 5.0);
	float plasma2 = sin(uv.y * 12.0 - custom_time * 4.0 + uv.x * 5.0);
	float activity = (plasma1 + plasma2) * 0.5;
	
	vec4 color = base_color;
	
	// Adiciona manchas brilhantes
	color.rgb += vec3(smoothstep(0.4, 0.9, activity) * 0.3);
	
	// Brilho central
	float core_glow = 1.0 - smoothstep(0.0, 0.6, dist);
	color.rgb += vec3(core_glow * 0.4);

	// RECORTE IRREGULAR (Corrosão da Borda)
	// Usamos a 'activity' para "comer" as bordas de forma dinâmica
	float edge_noise = activity * 0.1; 
	
	// Borda muito mais suave (0.25 + noise) para parecer gasoso/instável
	float alpha = smoothstep(0.5, 0.25 + edge_noise, dist);

	COLOR = color;
	COLOR.a *= alpha;
}