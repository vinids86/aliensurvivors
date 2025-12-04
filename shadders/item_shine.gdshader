shader_type canvas_item;

uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shine_speed : hint_range(0.0, 10.0) = 3.0;
uniform float shine_size : hint_range(0.01, 1.0) = 0.1;

void fragment() {
	vec4 curr_color = texture(TEXTURE, UV);
	
	// Cria uma faixa diagonal que se move com o tempo
	float shine = step(1.0 - shine_size, 0.5 + 0.5 * sin(UV.x - UV.y + TIME * shine_speed));
	
	// Aplica o brilho apenas onde o sprite existe (alpha > 0)
	vec3 final_color = mix(curr_color.rgb, shine_color.rgb, shine * curr_color.a);
	
	COLOR = vec4(final_color, curr_color.a);
}