shader_type spatial;

render_mode unshaded;
//render_mode depth_draw_alpha_prepass;

uniform float speed = 1.0;
uniform int iterations = 20;
uniform float iteration_spacing = 1.0;
uniform float even_brightness = 0.05; // 1/iterations
uniform float flash_brightness_factor = 10.0;

void fragment() {
	if (speed < 0.001) {
		ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	} else {
		vec2 blur_direction = vec2(0.5, 0.5) - SCREEN_UV;
		vec3 c = vec3(0.0);
		for (int i = 0; i < iterations; i++) {
			c += (speed*flash_brightness_factor + (1.0-speed)*20.0/float(iterations))*even_brightness*texture(SCREEN_TEXTURE, SCREEN_UV - speed*iteration_spacing*float(i)*blur_direction/float(iterations)).rgb;
		}
		ALBEDO = c;
	}
}