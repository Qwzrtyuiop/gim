shader_type canvas_item;

uniform vec2 displayed_size = vec2(1.0);
const int OUTLINE_PX = 2;
varying vec4 portrait_tint;

void vertex() {
	portrait_tint = COLOR;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float interior_alpha = original.a;
	// Erode inward by two displayed pixels to paint the outline over the art.
	for (int y = -OUTLINE_PX; y <= OUTLINE_PX; y++) {
		for (int x = -OUTLINE_PX; x <= OUTLINE_PX; x++) {
			if (x * x + y * y <= OUTLINE_PX * OUTLINE_PX) {
				vec2 sample_uv = UV + vec2(float(x), float(y)) / displayed_size;
				float neighbor_alpha = 0.0;
				if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThanEqual(sample_uv, vec2(1.0)))) {
					neighbor_alpha = texture(TEXTURE, sample_uv).a;
				}
				interior_alpha = min(interior_alpha, neighbor_alpha);
			}
		}
	}
	// Black replaces edge colors; the original silhouette and transparency stay intact.
	vec3 color = original.rgb * interior_alpha / max(original.a, 0.00001);
	COLOR = vec4(color, original.a) * portrait_tint;
}
