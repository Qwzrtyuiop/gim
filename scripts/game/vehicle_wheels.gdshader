shader_type canvas_item;

uniform vec4 wheel_0;
uniform vec4 wheel_1;
uniform vec2 hub_fractions;
uniform vec2 wheel_angles = vec2(0.0);
uniform float tire_highlight_strength = 0.16;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
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
	result.a = original.a;
	COLOR = result * sprite_tint;
}
