shader_type canvas_item;
render_mode unshaded;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform bool star = false;
uniform bool circle = false;
uniform vec2 circle_center = vec2(0.5, 0.5);

void fragment() {
	float opacity = coverage;
	if (circle) {
		vec2 size = vec2(480.0, 270.0);
		vec2 center = circle_center * size;
		vec2 p = floor(UV * size) + vec2(0.5) - center;
		// Reach the farthest corner even when Fatkid is away from screen center.
		float radius = (1.0 - coverage) * length(max(center, size - center));
		opacity = length(p) < radius ? 0.0 : 1.0;
		if (coverage <= 0.0) { opacity = 0.0; }
		if (coverage >= 1.0) { opacity = 1.0; }
	} else if (star) {
		// Evaluate at native pixel centers for a sharp five-point aperture.
		vec2 p = floor(UV * vec2(480.0, 270.0)) + vec2(0.5) - vec2(240.0, 135.0);
		float radius = (1.0 - coverage) * 720.0;
		bool inside = false;
		vec2 previous = vec2(0.0, -radius);
		for (int i = 1; i <= 10; i++) {
			float angle = -1.570796327 + float(i) * 0.628318531;
			float r = (i % 2 == 0) ? radius : radius * 0.45;
			vec2 current = vec2(cos(angle), sin(angle)) * r;
			if ((current.y > p.y) != (previous.y > p.y)) {
				float crossing = (previous.x - current.x) * (p.y - current.y) / (previous.y - current.y) + current.x;
				if (p.x < crossing) { inside = !inside; }
			}
			previous = current;
		}
		opacity = inside ? 0.0 : 1.0;
		if (coverage <= 0.0) { opacity = 0.0; }
		if (coverage >= 1.0) { opacity = 1.0; }
	}
	COLOR = vec4(0.0, 0.0, 0.0, opacity);
}
