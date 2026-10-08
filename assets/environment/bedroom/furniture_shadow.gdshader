shader_type canvas_item;
render_mode unshaded;
// The furniture silhouette is projected onto the floor by its node transform.
// A few neighboring alpha taps soften its edge without a viewport/blur pass.
void fragment() {
    vec2 d = TEXTURE_PIXEL_SIZE * 12.0;
    float a = texture(TEXTURE, UV).a * 0.20;
    a += texture(TEXTURE, UV + vec2(d.x, 0.0)).a * 0.12;
    a += texture(TEXTURE, UV - vec2(d.x, 0.0)).a * 0.12;
    a += texture(TEXTURE, UV + vec2(0.0, d.y)).a * 0.12;
    a += texture(TEXTURE, UV - vec2(0.0, d.y)).a * 0.12;
    a += texture(TEXTURE, UV + d).a * 0.08;
    a += texture(TEXTURE, UV - d).a * 0.08;
    a += texture(TEXTURE, UV + vec2(d.x, -d.y)).a * 0.08;
    a += texture(TEXTURE, UV + vec2(-d.x, d.y)).a * 0.08;
    COLOR = vec4(0.19, 0.10, 0.075, a * mix(0.13, 0.27, UV.y));
}
