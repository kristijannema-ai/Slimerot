shader_type canvas_item;
render_mode unshaded;
// A small relief response to the room's upper-left warm light. Original art is
// sampled unchanged; no normal-map texture or full-screen lighting pass is needed.
uniform float relief_strength : hint_range(0.0, 1.0) = 0.42;
float height_at(vec4 sample_color) {
    return dot(sample_color.rgb, vec3(0.299, 0.587, 0.114)) * sample_color.a;
}
void fragment() {
    vec4 art = texture(TEXTURE, UV);
    vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
    float dx = height_at(texture(TEXTURE, UV + vec2(step_uv.x, 0.0))) - height_at(texture(TEXTURE, UV - vec2(step_uv.x, 0.0)));
    float dy = height_at(texture(TEXTURE, UV + vec2(0.0, step_uv.y))) - height_at(texture(TEXTURE, UV - vec2(0.0, step_uv.y)));
    float relief = clamp((-dx - dy) * relief_strength, -0.10, 0.10);
    float broad_light = 1.055 - UV.x * 0.055 - UV.y * 0.045;
    vec3 warm = vec3(1.015, 1.0, 0.98);
    COLOR = vec4(COLOR.rgb * warm * (broad_light + relief), COLOR.a);
}
