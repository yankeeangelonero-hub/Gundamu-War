shader_type spatial;
// Screen-space ink pass for cel mode: inks INTERIOR creases (normal discontinuities,
// the edges inverted-hull misses inside a mesh / on bright surfaces) and OCCLUSION
// boundaries (depth jumps — e.g. debris stacked on debris, mech over building).
// No posterise — the cel material already bands; this only draws the lines.
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled;

// Transparent INK OVERLAY: draws ink only on edge pixels (alpha = edge), nothing
// elsewhere — so it never occludes transparent FX (beams, projectiles, explosions).
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

uniform float thickness = 1.1;
uniform float interior_edge = 0.5;     // normal-difference threshold (creases)
uniform float occlusion_edge = 0.03;   // relative depth-jump threshold (overlaps)
uniform vec3 ink : source_color = vec3(0.07, 0.07, 0.10);
uniform float ink_strength = 0.9;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);   // clip-space fullscreen (reversed-z near = 1.0)
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(v.z / v.w);
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;

	// Interior creases / edges within & between meshes (normal discontinuity).
	vec3 nc = texture(normal_tex, SCREEN_UV).rgb * 2.0 - 1.0;
	vec3 nr = texture(normal_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb * 2.0 - 1.0;
	vec3 nu = texture(normal_tex, SCREEN_UV + vec2(0.0, px.y)).rgb * 2.0 - 1.0;
	vec3 nl = texture(normal_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb * 2.0 - 1.0;
	vec3 nd = texture(normal_tex, SCREEN_UV - vec2(0.0, px.y)).rgb * 2.0 - 1.0;
	float ne = (1.0 - dot(nc, nr)) + (1.0 - dot(nc, nu)) + (1.0 - dot(nc, nl)) + (1.0 - dot(nc, nd));
	float n_edge = step(interior_edge, ne);

	// Occlusion boundaries: linearised depth jumps (one object in front of another).
	mat4 ip = INV_PROJECTION_MATRIX;
	float dc = lin_depth(SCREEN_UV, ip);
	float de = max(max(abs(dc - lin_depth(SCREEN_UV + vec2(px.x, 0.0), ip)),
					   abs(dc - lin_depth(SCREEN_UV - vec2(px.x, 0.0), ip))),
				   max(abs(dc - lin_depth(SCREEN_UV + vec2(0.0, px.y), ip)),
					   abs(dc - lin_depth(SCREEN_UV - vec2(0.0, px.y), ip))));
	float d_edge = step(occlusion_edge * max(dc, 1.0), de);

	float edge = clamp(max(n_edge, d_edge), 0.0, 1.0);
	ALBEDO = ink;
	ALPHA = edge * ink_strength;   // ink only on edges; alpha 0 elsewhere → FX show through
}
