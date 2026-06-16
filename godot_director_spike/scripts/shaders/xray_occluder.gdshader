shader_type spatial;
// X-ray occluder (spec 2026-06-16): dissolves wall fragments along the camera->mech
// sightline so the real mech shows through a soft round window. Lit, roughness 0.7,
// to match the buildings' StandardMaterial3D. Order-independent ordered-dither discard.

global uniform vec3 xray_mech_a;
global uniform vec3 xray_mech_b;
global uniform float xray_radius;
global uniform float xray_softness;
// Per-mech gate (0..1): the director fades these up only while that mech is
// actually occluded by a building, so a clear-view mech never carves a window.
global uniform float xray_enable_a;
global uniform float xray_enable_b;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 emission_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float sightline_cut(vec3 p, vec3 cam, vec3 m, float radius, float softness) {
	vec3 seg = m - cam;
	float seg2 = dot(seg, seg);
	if (seg2 < 0.0001) { return 0.0; }
	float t = dot(p - cam, seg) / seg2;
	if (t <= 0.0 || t >= 1.0) { return 0.0; }
	vec3 proj = cam + t * seg;
	float perp = distance(p, proj);
	return 1.0 - smoothstep(radius - softness, radius, perp);
}

// 4x4 ordered (Bayer) dither: regular halftone screentone instead of white
// noise. Threshold in [0,1) keyed by screen pixel; reads clean and intentional.
const float BAYER_4X4[16] = {
	 0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	 3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
};

float bayer_threshold(vec2 fc) {
	int ix = int(mod(fc.x, 4.0));
	int iy = int(mod(fc.y, 4.0));
	return BAYER_4X4[iy * 4 + ix];
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	float cut = max(
		sightline_cut(world_pos, cam, xray_mech_a, xray_radius, xray_softness) * xray_enable_a,
		sightline_cut(world_pos, cam, xray_mech_b, xray_radius, xray_softness) * xray_enable_b);
	if (cut > bayer_threshold(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.7;
	EMISSION = emission_col.rgb * emission_energy;
}
