shader_type canvas_item;
render_mode unshaded;

uniform sampler2D lair_tex : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;
uniform float wipe_x = 480.0;
uniform float flash = 0.0;
uniform float rim_hot = 1.0;
uniform vec2 field = vec2(480.0, 270.0);

const vec3 EMBER_0 = vec3(0.909804, 0.603922, 0.188235);
const vec3 EMBER_1 = vec3(0.815686, 0.415686, 0.094118);
const vec3 EMBER_2 = vec3(0.690196, 0.290196, 0.070588);
const vec3 EMBER_3 = vec3(0.478431, 0.164706, 0.062745);

void fragment() {
	vec4 color = vec4(0.0);
	bool show = false;
	if (flash > 0.5) {
		color = vec4(1.0, 1.0, 1.0, 1.0);
		show = true;
	} else {
		vec2 uv = UV;
		float x = uv.x * field.x;
		float mask = texture(mask_tex, uv).a;
		bool open = mask > 0.5;
		bool wiped = x >= wipe_x;
		vec2 px = vec2(1.0 / field.x, 1.0 / field.y);
		float near = max(
			max(texture(mask_tex, uv + vec2(px.x, 0.0)).a, texture(mask_tex, uv - vec2(px.x, 0.0)).a),
			max(texture(mask_tex, uv + vec2(0.0, px.y)).a, texture(mask_tex, uv - vec2(0.0, px.y)).a)
		);
		bool rim = !open && near > 0.5 && !wiped;
		if (rim) {
			color = vec4(rim_hot > 0.5 ? EMBER_0 : EMBER_1, 1.0);
			show = true;
		} else if (open || wiped) {
			show = true;
			if (wiped && x < wipe_x + 4.0) {
				float band = floor(x - wipe_x);
				vec3 edge = EMBER_3;
				if (band < 1.0) {
					edge = EMBER_0;
				} else if (band < 2.0) {
					edge = EMBER_1;
				} else if (band < 3.0) {
					edge = EMBER_2;
				}
				color = vec4(edge, 1.0);
			} else if (wiped && x < wipe_x + 16.0) {
				vec2 cell = floor(vec2(x, uv.y * field.y) / 3.0);
				float spark = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
				if (spark > 0.93) {
					color = vec4(spark > 0.965 ? EMBER_0 : EMBER_1, 1.0);
				} else {
					color = texture(lair_tex, uv);
				}
			} else {
				color = texture(lair_tex, uv);
			}
		}
	}
	if (!show) {
		discard;
	}
	COLOR = color;
}
