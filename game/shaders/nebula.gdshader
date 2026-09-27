shader_type canvas_item;
// Animated dream nebula with twinkling pixel stars (title / clinic / ending).

uniform vec4 c1 : source_color = vec4(0.07, 0.05, 0.17, 1.0);
uniform vec4 c2 : source_color = vec4(0.32, 0.12, 0.40, 1.0);
uniform vec4 c3 : source_color = vec4(0.95, 0.55, 0.75, 1.0);
uniform float speed = 0.03;
uniform float stars = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(1.78, 1.0) * 3.0;
	float t = TIME * speed;
	float n = fbm(uv + vec2(t, -t * 0.5) + fbm(uv * 0.7 - t));
	vec3 col = mix(c1.rgb, c2.rgb, smoothstep(0.3, 0.72, n));
	col = mix(col, c3.rgb, smoothstep(0.62, 0.92, n) * 0.55);
	vec2 g = floor(UV * vec2(320.0, 180.0));
	float s = step(0.996, hash(g));
	float tw = 0.5 + 0.5 * sin(TIME * 2.0 + hash(g + 3.0) * 20.0);
	col += s * tw * stars;
	COLOR = vec4(col, 1.0);
}
