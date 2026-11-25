shader_type canvas_item;
render_mode unshaded;
uniform bool active = true;
uniform int phase = 0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (!active) {
		COLOR = source;
	} else {
		float lightness = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		vec3 ink = vec3(43.0, 45.0, 66.0) / 255.0;
		vec3 dark_green = vec3(36.0, 85.0, 63.0) / 255.0;
		vec3 green = vec3(99.0, 168.0, 74.0) / 255.0;
		vec3 lime = vec3(211.0, 254.0, 28.0) / 255.0;
		vec3 pale = vec3(129.0, 199.0, 132.0) / 255.0;
		vec3 tint = lightness < 0.20 ? ink : (lightness < 0.45 ? dark_green : (lightness < 0.72 ? green : lime));
		// A moving two-pixel band suggests a magical scan without smearing the sprite.
		if (lightness >= 0.45 && int(floor(UV.y / TEXTURE_PIXEL_SIZE.y) + float(phase * 3)) % 12 < 2) {
			tint = pale;
		}
		COLOR = vec4(tint, source.a);
	}
}
