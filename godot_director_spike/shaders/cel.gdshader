shader_type spatial;
// Cel shader after eldskald/godot4-cel-shader (MIT). Same light() math — ramp-
// sampled toon diffuse, blinn-phong toonified specular, fresnel rim — but the
// project-global uniforms are made per-material so the spike is self-contained.
// An inverted-hull outline (cel_outline.gdshader) is attached via next_pass.

uniform vec4 color : source_color = vec4(0.6, 0.6, 0.66, 1.0);
uniform sampler2D diffuse_curve : repeat_disable;   // banded ramp, supplied in code
uniform vec4 specular : source_color = vec4(0.6, 0.6, 0.65, 0.5);
uniform float specular_smoothness : hint_range(0.0, 1.0) = 0.1;
uniform vec4 fresnel : source_color = vec4(0.7, 0.8, 1.0, 0.35);
uniform float fresnel_smoothness : hint_range(0.0, 1.0) = 0.1;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

varying vec3 SPECULAR_COLOR;
varying float SPECULAR_STRENGTH;
varying vec3 FRESNEL_COLOR;
varying float FRESNEL_STRENGTH;

// Full RGB so the ramp can TINT (cool shadows), not just darken.
vec3 ramp_rgb(vec3 light, vec3 normal) {
	return texture(diffuse_curve, vec2(dot(light, normal), 0.0)).rgb;
}

float is_lit(vec3 light, vec3 normal, float attenuation) {
	return attenuation * texture(diffuse_curve, vec2(dot(light, normal), 0.0)).r;
}

void fragment() {
	ALBEDO = color.rgb;
	EMISSION = emission * emission_energy;
	// Flat — no PBR environment reflection (the cel sheen is done in light()).
	SPECULAR = 0.0;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR_COLOR = specular.rgb;
	SPECULAR_STRENGTH = specular.a;
	FRESNEL_COLOR = fresnel.rgb;
	FRESNEL_STRENGTH = fresnel.a;
}

void light() {
	// Banded toon diffuse: sample the (coloured) ramp by N·L — tints shadows.
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * ramp_rgb(LIGHT, NORMAL);

	// Hard anime specular: blinn-phong half-vector, thresholded into a blob.
	vec3 half_v = normalize(VIEW + LIGHT);
	float gloss = pow(2.0, 8.0 * (1.0 - SPECULAR_STRENGTH));
	float intensity = pow(max(dot(NORMAL, half_v), 0.0), gloss * gloss);
	SPECULAR_LIGHT += LIGHT_COLOR * SPECULAR_COLOR * is_lit(LIGHT, NORMAL, ATTENUATION)
			* smoothstep(0.05, 0.05 + specular_smoothness, intensity);

	// Toonified fresnel rim.
	float fresnel_dot = 1.0 - dot(NORMAL, VIEW);
	float fresnel_threshold = pow(1.0 - FRESNEL_STRENGTH, max(dot(LIGHT, NORMAL), 0.0));
	SPECULAR_LIGHT += LIGHT_COLOR * FRESNEL_COLOR * is_lit(LIGHT, NORMAL, ATTENUATION)
			* smoothstep(fresnel_threshold - fresnel_smoothness / 2.0,
					fresnel_threshold + fresnel_smoothness / 2.0, fresnel_dot);
}
