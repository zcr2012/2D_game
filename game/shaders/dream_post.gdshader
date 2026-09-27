shader_type canvas_item;
// Full-screen post effect for the dream world, driven by the Dream Editor:
//   emotion  -> saturation / tint
//   reality  -> wave distortion, chromatic aberration, glitch bands, vignette
//   time     -> night darkness with lights (player + lamps / hidden memories)

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float saturation = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount = 0.0;
uniform float wave = 0.0;
uniform float aberration = 0.0;
uniform float glitch = 0.0;
uniform float night = 0.0;
uniform vec2 light_pos = vec2(0.5, 0.5);
uniform vec2 lamp_pos[8];
uniform float lamp_count = 0.0;
uniform float vignette = 0.25;
uniform vec4 vignette_color : source_color = vec4(0.05, 0.02, 0.1, 1.0);
uniform float flash = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	uv.x += sin(uv.y * 28.0 + t * 2.2) * 0.0035 * wave;
	uv.y += cos(uv.x * 22.0 + t * 1.7) * 0.0025 * wave;
	float row = floor(uv.y * 48.0);
	float band = step(0.965, hash(row * 7.13 + floor(t * 14.0)));
	uv.x += (hash(row + floor(t * 20.0)) - 0.5) * band * glitch * 0.08;

	float ab = aberration * 0.0035 + band * glitch * 0.01;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = mix(col, col * tint.rgb, tint_amount);

	// night lighting
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - light_pos) * vec2(aspect, 1.0);
	float light = smoothstep(0.30, 0.04, length(d));
	for (int i = 0; i < 8; i++) {
		if (float(i) < lamp_count) {
			vec2 dl = (SCREEN_UV - lamp_pos[i]) * vec2(aspect, 1.0);
			light = max(light, smoothstep(0.11, 0.0, length(dl)) * 0.95);
		}
	}
	vec3 dark = col * vec3(0.16, 0.18, 0.40);
	vec3 lit = col * vec3(1.05, 0.97, 0.85);
	col = mix(col, mix(dark, lit, light), night);

	float v = smoothstep(0.35, 0.95, length((SCREEN_UV - 0.5) * vec2(aspect, 1.0)) * 1.1);
	col = mix(col, vignette_color.rgb, v * vignette);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, 1.0);
}
