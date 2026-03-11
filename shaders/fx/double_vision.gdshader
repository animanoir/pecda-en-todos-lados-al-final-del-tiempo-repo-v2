shader_type canvas_item;

// -- Desaturation --
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;

// -- Ghost / Double vision --
uniform float ghost : hint_range(0.0, 1.0) = 0.0;
uniform float ghost_speed : hint_range(0.0, 20.0) = 4.0;
uniform float ghost_frequency : hint_range(0.0, 200.0) = 25.0;
uniform float ghost_amplitude : hint_range(0.0, 0.1) = 0.015;
uniform float ghost_spread : hint_range(0.0, 0.5) = 0.15;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture,
		filter_linear_mipmap_anisotropic;

void fragment() {
	vec4 base_color = texture(SCREEN_TEXTURE, SCREEN_UV);

	// -- Desaturation --
	float luminance = dot(base_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 desaturated = mix(base_color.rgb, vec3(luminance), desaturation);

	// -- Ghost / Double vision --
	vec3 final_color = desaturated;

	if (ghost > 0.001) {
		// Create an offset copy of the screen — the "double".
		vec2 center = vec2(0.5, 0.5);
		vec2 offset = (SCREEN_UV - center) * ghost_spread;
		vec2 ghost_uv = SCREEN_UV + offset;

		// Vibrate the ghost horizontally AND vertically.
		ghost_uv.x += cos(
				TIME * ghost_speed + (SCREEN_UV.y * ghost_frequency)
		) * ghost_amplitude;
		ghost_uv.y += sin(
				TIME * ghost_speed * 0.7 + (SCREEN_UV.x * ghost_frequency * 0.5)
		) * ghost_amplitude * 0.5;

		// Sample the ghost.
		vec3 ghost_color = texture(SCREEN_TEXTURE, ghost_uv).rgb;

		// Desaturate the ghost too.
		float ghost_lum = dot(ghost_color, vec3(0.2126, 0.7152, 0.0722));
		ghost_color = mix(ghost_color, vec3(ghost_lum), desaturation);

		// Screen blend — brighter and more visible than additive * 0.4.
		vec3 blended = final_color + ghost_color - (final_color * ghost_color);
		final_color = mix(final_color, blended, ghost * 0.7);
	}

	COLOR.rgb = final_color;
	COLOR.a = 1.0;
}