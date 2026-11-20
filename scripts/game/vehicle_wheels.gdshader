shader_type canvas_item;

uniform vec4 wheel_0;
uniform vec4 wheel_1;
uniform vec2 hub_fractions;
uniform vec2 wheel_angles = vec2(0.0);
uniform float tire_highlight_strength = 0.16;
uniform bool paint_enabled = false;
uniform sampler2D paint_mask : filter_nearest, repeat_disable;
uniform vec4 main_paint_color : source_color = vec4(0.0);
uniform vec4 highlight_paint_color : source_color = vec4(0.0);
uniform vec4 main_paint_reference : source_color = vec4(0.95294, 0.72549, 0.10196, 1.0);
uniform vec4 highlight_paint_reference : source_color = vec4(0.63529, 0.15294, 0.16471, 1.0);
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

vec3 rgb_to_hsv(vec3 color) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(color.bg, k.wz), vec4(color.gb, k.xy), step(color.b, color.g));
	vec4 q = mix(vec4(p.xyw, color.r), vec4(color.r, p.yzx), step(p.x, color.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.00001)), d / (q.x + 0.00001), q.x);
}

vec3 hsv_to_rgb(vec3 color) {
	vec3 p = abs(fract(color.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return color.z * mix(vec3(1.0), clamp(p - 1.0, vec3(0.0), vec3(1.0)), color.y);
}

vec3 repaint(vec3 original, vec4 target, vec3 reference, float coverage) {
	vec3 source_hsv = rgb_to_hsv(original);
	vec3 target_hsv = rgb_to_hsv(target.rgb);
	vec3 reference_hsv = rgb_to_hsv(reference);
	// Keep shading/saturation detail while unifying differently colored trim.
	// The red mask also covers gold stripes, whose old hue must not carry over.
	vec3 painted_hsv = vec3(
		target_hsv.x,
		clamp(source_hsv.y + target_hsv.y - reference_hsv.y, 0.0, 1.0),
		clamp(source_hsv.z * target_hsv.z / max(reference_hsv.z, 0.00001), 0.0, 1.0)
	);
	return mix(original, hsv_to_rgb(painted_hsv), coverage * target.a);
}

float tire_highlight(vec2 p, float radius, float angle, vec4 original) {
	// A short travelling tire highlight makes even plain circular hubcaps read
	// as rolling. Restrict it to opaque, dark rubber so bright forks stay fixed.
	float ring = smoothstep(0.76, 0.81, radius) * (1.0 - smoothstep(0.91, 0.96, radius));
	float arc = pow(max(0.0, cos(atan(p.y, p.x) - angle)), 14.0);
	float dark_rubber = 1.0 - smoothstep(0.25, 0.40, max(original.r, max(original.g, original.b)));
	return tire_highlight_strength * ring * arc * dark_rubber * original.a;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec4 result = original;
	for (int i = 0; i < 2; i++) {
		vec4 wheel = i == 0 ? wheel_0 : wheel_1;
		float hub_fraction = hub_fractions[i];
		float angle = wheel_angles[i];
		vec2 p = (UV / TEXTURE_PIXEL_SIZE - wheel.xy) / max(wheel.zw, vec2(1.0));
		float radius = length(p);
		if (radius < 1.0) {
			if (hub_fraction > 0.0 && radius < hub_fraction) {
				float c = cos(angle);
				float s = sin(angle);
				vec2 rotated = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
				vec2 sample_uv = (wheel.xy + rotated * wheel.zw) * TEXTURE_PIXEL_SIZE;
				vec4 hub = texture(TEXTURE, sample_uv);
				float blend = 1.0 - smoothstep(max(0.0, hub_fraction - 0.05), hub_fraction, radius);
				result = mix(original, hub, blend);
			}
			result.rgb += vec3(tire_highlight(p, radius, angle, original));
		}
	}
	if (paint_enabled) {
		vec4 mask = texture(paint_mask, UV);
		// White/unmarked pixels never count as paint. Alpha includes soft edges.
		float colored = mask.a * (1.0 - step(0.4, mask.b)) * step(0.5, mask.r);
		float main_coverage = colored * step(0.5, mask.g);
		float highlight_coverage = colored * (1.0 - step(0.4, mask.g));
		result.rgb = repaint(result.rgb, main_paint_color, main_paint_reference.rgb, main_coverage);
		result.rgb = repaint(result.rgb, highlight_paint_color, highlight_paint_reference.rgb, highlight_coverage);
	}
	result.a = original.a;
	COLOR = result * sprite_tint;
}
