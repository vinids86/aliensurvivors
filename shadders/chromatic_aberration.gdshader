shader_type canvas_item;

// Acesso à tela inteira
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Intensidade do efeito (controlado pelo Trauma da câmera)
uniform float chaos_level : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// A força do desvio das cores.
	// Elevamos ao quadrado para que valores baixos sejam sutis, e altos sejam drásticos.
	float strength = chaos_level * chaos_level * 0.02;
	
	// Direção do deslocamento (simples, baseada no centro)
	vec2 center = vec2(0.5, 0.5);
	vec2 to_center = center - uv;
	
	// Canal Vermelho (Desloca para um lado)
	float r = texture(screen_texture, uv + to_center * strength).r;
	
	// Canal Verde (Fica parado - âncora visual)
	float g = texture(screen_texture, uv).g;
	
	// Canal Azul (Desloca para o oposto)
	float b = texture(screen_texture, uv - to_center * strength).b;
	
	// Vinheta Dinâmica (Escurece as bordas quando o trauma é alto)
	float dist = length(to_center);
	float vignette = smoothstep(0.8, 0.2, dist * chaos_level);
	
	vec3 final_color = vec3(r, g, b);
	
	// Aplica vinheta (subtrai escuridão baseada no chaos)
	final_color -= vec3(dist * chaos_level * 0.5);

	COLOR = vec4(final_color, 1.0);
}