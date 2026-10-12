shader_type canvas_item;
// Viñeta suave en los bordes para dar profundidad (no tapa la acción).
uniform float strength : hint_range(0.0, 1.0) = 0.38;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 1.1));
	float v = smoothstep(0.38, 0.9, d);
	COLOR = vec4(0.0, 0.0, 0.06, v * strength);
}
