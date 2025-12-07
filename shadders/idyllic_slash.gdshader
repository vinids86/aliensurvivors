shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float arc_angle : hint_range(0.0, 360.0) = 130.0;
uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap;

const float PI_VAL = 3.14159265359;

void fragment() {
	vec2 uv = UV - 0.5;

	float dist = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x); // 0 é Direita

	// --- GEOMETRIA ---
	float half_rad = radians(arc_angle) / 2.0;

	// Máscara Angular
	float in_cone = step(abs(angle), half_rad);

	// Sweep
	float angle_progress = (angle + half_rad) / (half_rad * 2.0);
	float tail_length = 0.4;
	float head_pos = progress * (1.0 + tail_length);

	float sweep_mask = smoothstep(head_pos - tail_length, head_pos, angle_progress);
	sweep_mask *= step(angle_progress, head_pos);

	// Anel
	float thickness = 0.3;
	float radius = 0.7;
	float ring = 1.0 - smoothstep(thickness * 0.5, thickness, abs(dist - radius));

	// --- DISSOLUÇÃO ---
	float noise = texture(noise_tex, uv + vec2(progress, 0.0)).r;

	// --- COR FINAL ---
	float alpha = in_cone * sweep_mask * ring;
	alpha *= smoothstep(0.2, 0.8, noise + 0.2);
	alpha *= 1.0 - smoothstep(0.9, 1.0, progress);

	vec3 color = mix(edge_color.rgb, base_color.rgb, ring * sweep_mask);
	color += base_color.rgb * smoothstep(0.8, 1.0, sweep_mask) * 2.0;

	COLOR = vec4(color, alpha * base_color.a);
}