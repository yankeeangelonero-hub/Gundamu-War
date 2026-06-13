shader_type spatial;
// Full-screen post pass for an early-2000s Gundam-anime look: posterised cel
// banding + ink outlines from depth & normal discontinuities. Camera-child quad.
// Writing ALPHA pushes it to the transparent pass so the screen texture holds
// the fully-rendered opaque scene.
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

uniform float outline_thickness = 1.2;
uniform float depth_edge = 0.06;        // relative depth jump that counts as an edge
uniform float normal_edge = 1.1;        // crease sensitivity (higher = only strong creases)
uniform vec3 ink : source_color = vec3(0.06, 0.05, 0.08);
uniform float bands = 4.0;              // cel posterisation steps (banding on a bright base)
uniform float saturation = 1.1;
uniform float lift = 0.12;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);   // clip-space fullscreen (reversed-z near = 1.0)
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(v.z / v.w);
}

void fragment() {
	vec2 px = outline_thickness / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// --- normal-difference edges (creases + silhouettes) ---
	vec3 nc = texture(normal_tex, SCREEN_UV).rgb * 2.0 - 1.0;
	vec3 nr = texture(normal_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb * 2.0 - 1.0;
	vec3 nu = texture(normal_tex, SCREEN_UV + vec2(0.0, px.y)).rgb * 2.0 - 1.0;
	vec3 nl = texture(normal_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb * 2.0 - 1.0;
	vec3 nd = texture(normal_tex, SCREEN_UV - vec2(0.0, px.y)).rgb * 2.0 - 1.0;
	float ne = (1.0 - dot(nc, nr)) + (1.0 - dot(nc, nu)) + (1.0 - dot(nc, nl)) + (1.0 - dot(nc, nd));
	float n_edge = step(normal_edge, ne);

	// --- linearised depth edges (silhouettes) ---
	mat4 ip = INV_PROJECTION_MATRIX;
	float dc = lin_depth(SCREEN_UV, ip);
	float dmax = max(max(abs(dc - lin_depth(SCREEN_UV + vec2(px.x, 0.0), ip)),
						 abs(dc - lin_depth(SCREEN_UV - vec2(px.x, 0.0), ip))),
					 max(abs(dc - lin_depth(SCREEN_UV + vec2(0.0, px.y), ip)),
						 abs(dc - lin_depth(SCREEN_UV - vec2(0.0, px.y), ip))));
	float d_edge = step(depth_edge * max(dc, 1.0), dmax);

	float edge = clamp(max(n_edge, d_edge), 0.0, 1.0);

	// --- cel grade: lift, saturate, posterise, then ink the edges ---
	col += lift;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = floor(col * bands + 0.5) / bands;
	col = mix(col, ink, edge);

	ALBEDO = col;
	ALPHA = 1.0;   // route to transparent pass so screen_tex = full opaque scene
}
