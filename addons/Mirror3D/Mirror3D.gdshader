shader_type spatial;
render_mode unshaded; // Mirror texture is already shaded
render_mode cull_disabled; // Show both sides of mirror

uniform vec4 color : source_color;

uniform sampler2D mirror_texture_linear : source_color, filter_linear_mipmap;
uniform sampler2D mirror_texture_nearest : source_color, filter_nearest_mipmap;
uniform bool use_mirror_texture_linear = true;

uniform sampler2D distortion_texture_linear : source_color, filter_linear_mipmap;
uniform sampler2D distortion_texture_nearest : source_color, filter_nearest_mipmap;
uniform bool use_distortion_texture_linear = true;
uniform float distortion_strength : hint_range(0, 100, 0.01);

uniform sampler2D mask_texture_linear : source_color, filter_linear_mipmap;
uniform sampler2D mask_texture_nearest : source_color, filter_nearest_mipmap;
uniform bool use_mask_texture_linear = true;

void vertex() {
	// Flip mirror horizontally
	UV.x = 1.0 - UV.x;
}

void fragment() {
	// Get correct UV for both sides
	vec2 uv = FRONT_FACING ? UV : vec2(1.0 - UV.x, UV.y);

	// Sample distortion texture
	vec4 distortion_sample = use_distortion_texture_linear
		? texture(distortion_texture_linear, uv)
		: texture(distortion_texture_nearest, uv);
	// Get distortion offset from distortion sample
	float distortion_offset = distortion_sample.r;
	// Center distortion offset (map to [-1, 1] region)
	distortion_offset = (distortion_offset * 2.0) - 1.0;
	// Distort UV
	vec2 distorted_uv = uv + (distortion_offset * distortion_strength / VIEWPORT_SIZE);

	// Sample viewport texture at distorted position
	vec4 mirror_sample = use_mirror_texture_linear
		? texture(mirror_texture_linear, distorted_uv)
		: texture(mirror_texture_nearest, distorted_uv);

	// Sample mask texture
	vec4 mask_sample = use_mask_texture_linear
		? texture(mask_texture_linear, UV)
		: texture(mask_texture_nearest, UV);
	// Apply mask
	mirror_sample *= mask_sample;

	// Mix sample and color modulate
	ALBEDO = mirror_sample.rgb * color.rgb;
	ALPHA = mirror_sample.a * color.a;
}