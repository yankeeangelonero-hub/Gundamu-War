shader_type spatial;
// X-ray occluder (spec 2026-06-16): dissolves wall fragments along the camera->mech
// sightline so the real mech shows through a soft round window. Lit, roughness 0.7,
// to match the buildings' StandardMaterial3D. Order-independent hashed discard.

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

float hash12(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	float cut = max(
		sightline_cut(world_pos, cam, xray_mech_a, xray_radius, xray_softness) * xray_enable_a,
		sightline_cut(world_pos, cam, xray_mech_b, xray_radius, xray_softness) * xray_enable_b);
	if (cut > hash12(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.7;
	EMISSION = emission_col.rgb * emission_energy;
}
