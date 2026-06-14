shader_type spatial;
// Inverted-hull outline, after eldskald/godot4-cel-shader (MIT). Attached as the
// cel material's next_pass: renders back faces extruded along the normal in clip
// space, giving a constant-width ink line. Globals adapted to per-material uniforms.
render_mode cull_front, unshaded, depth_draw_never;

uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform float outline_width : hint_range(0.0, 20.0) = 3.0;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	clip_position.xy += normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width;
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
