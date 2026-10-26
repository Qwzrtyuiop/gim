shader_type canvas_item;
render_mode unshaded;

uniform sampler2D marker_mask : filter_nearest, repeat_disable;
uniform vec2 logical_size = vec2(1280.0, 720.0);
uniform float elapsed = 0.0;
uniform float rain_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool indoor = false;
uniform bool strict_marker_colors = false;

float hash_value(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float marked(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 0.0;
	}
	vec4 sample_color = texture(marker_mask, uv);
	if (strict_marker_colors) {
		return step(0.5, sample_color.a) * step(160.0 / 255.0, sample_color.r)
			* step(sample_color.r, 240.0 / 255.0) * step(240.0 / 255.0, sample_color.g)
			* step(sample_color.b, 20.0 / 255.0);
	}
	return step(0.5, sample_color.a) * step(0.4, sample_color.r)
		* step(0.7, sample_color.g) * step(sample_color.b, 0.3);
}

float falling_rain(vec2 pixel) {
	float heavy = step(0.9, rain_strength);
	vec2 cell_size = vec2(20.0, 96.0);
	float length_pixels = mix(40.0, 64.0, heavy);
	float half_width = mix(1.2, 1.8, heavy);
	vec2 moving = vec2(pixel.x + pixel.y * 0.16,
		pixel.y - elapsed * mix(750.0, 1320.0, heavy));
	vec2 cell = floor(moving / cell_size);
	vec2 local = fract(moving / cell_size) * cell_size;
	float random_value = hash_value(cell);
	float allowed = step(random_value, mix(0.65, 0.95, heavy));
	// Keep complete streaks inside their cells instead of clipping longer tails.
	float line_x = half_width + 1.0 + hash_value(cell + vec2(17.0, 9.0))
		* (cell_size.x - 2.0 * (half_width + 1.0));
	float line_y = 1.0 + hash_value(cell + vec2(3.0, 41.0))
		* (cell_size.y - length_pixels - 2.0);
	float width_mask = 1.0 - step(half_width, abs(local.x - line_x));
	float length_mask = step(line_y, local.y) * (1.0 - step(line_y + length_pixels, local.y));
	return allowed * width_mask * length_mask;
}

float ground_splash(vec2 pixel, vec2 uv) {
	if (indoor) {
		return 0.0;
	}
	float heavy = step(0.9, rain_strength);
	float max_radius = mix(16.0, 20.0, heavy);
	vec2 cell_size = vec2(64.0, 40.0);
	vec2 cell = floor(pixel / cell_size);
	float clock = elapsed * mix(4.0, 6.6, heavy) + hash_value(cell + vec2(8.0, 19.0));
	float cycle = floor(clock);
	float age = fract(clock);
	vec2 seed = cell + vec2(cycle * 73.0, cycle * 11.0);
	if (hash_value(seed) > mix(0.24, 0.4, heavy)) {
		return 0.0;
	}
	vec2 jitter = vec2(hash_value(seed + vec2(5.0, 7.0)), hash_value(seed + vec2(13.0, 2.0))) - 0.5;
	vec2 center = (cell + vec2(0.5)) * cell_size + jitter * vec2(6.0, 4.0);
	float radius = mix(2.0, max_radius, age);
	vec2 shape = (pixel - center) / vec2(radius, max(0.85, radius * 0.28));
	float ring = 1.0 - smoothstep(0.10, 0.26, abs(length(shape) - 1.0));
	if (ring <= 0.0) {
		return 0.0;
	}
	// Require an opaque yellow center and room for the whole ripple. The final
	// per-fragment mask also clips irregular edges and transparent holes exactly.
	vec2 center_uv = center / logical_size;
	vec2 margin = (vec2(max_radius, max_radius * 0.28) * 1.3 + vec2(1.0)) / logical_size;
	float allowed = marked(center_uv) * marked(center_uv + vec2(margin.x, 0.0))
		* marked(center_uv - vec2(margin.x, 0.0))
		* marked(center_uv + vec2(0.0, margin.y)) * marked(center_uv - vec2(0.0, margin.y))
		* marked(center_uv + margin) * marked(center_uv - margin)
		* marked(center_uv + vec2(margin.x, -margin.y))
		* marked(center_uv + vec2(-margin.x, margin.y));
	return ring * allowed * marked(uv) * (1.0 - age) * (1.0 - age);
}

void fragment() {
	float heavy = step(0.9, rain_strength);
	vec2 pixel = floor(UV * logical_size);
	float streak = falling_rain(pixel);
	if (indoor) {
		streak *= marked(UV);
	}
	float ripple = ground_splash(pixel, UV);
	float alpha = max(streak * mix(0.36, 0.48, heavy), ripple * 0.72);
	COLOR = vec4(vec3(0.69, 0.85, 1.0), alpha * step(0.01, rain_strength));
}
