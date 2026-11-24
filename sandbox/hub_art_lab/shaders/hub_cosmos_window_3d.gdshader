shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Ventanal Panorámico Norte proyectando el SubViewport vivo de CosmosRootNode.
// Incluye destello de re-sintonización (retune_flash) al cambiar next_run_seed y sutil marco de cristal.

uniform sampler2D cosmos_tex : source_color, filter_linear, repeat_disable;
uniform vec4 glass_edge_tint : source_color = vec4(0.18, 0.42, 0.68, 1.0);
uniform vec4 astral_gold_color : source_color = vec4(0.91, 0.78, 0.44, 1.0);
uniform vec4 retune_color : source_color = vec4(0.32, 0.94, 1.0, 1.0);
uniform float retune_flash : hint_range(0.0, 1.0) = 0.0;
uniform float glass_sheen_strength : hint_range(0.0, 0.4) = 0.08;
uniform float brightness_boost : hint_range(0.5, 2.0) = 1.06;

void fragment() {
	vec2 uv = UV;
	if (retune_flash > 0.001) {
		float glitch = sin(uv.y * 46.0 + TIME * 42.0) * 0.022 * retune_flash;
		uv.x = clamp(uv.x + glitch, 0.0, 1.0);
	}

	vec3 col = texture(cosmos_tex, uv).rgb * brightness_boost;

	// Reflejo diagonal sutil de cristal panorámico
	float sheen_band = 1.0 - smoothstep(0.0, 0.16, abs((uv.x * 0.72 + uv.y * 0.45) - 0.58));
	col += glass_edge_tint.rgb * (sheen_band * glass_sheen_strength);

	// Parteluces sutiles de ventanal blindado en tercios exteriores (x = 0.22 y 0.78)
	float mullion_l = 1.0 - smoothstep(0.0015, 0.0055, abs(uv.x - 0.22));
	float mullion_r = 1.0 - smoothstep(0.0015, 0.0055, abs(uv.x - 0.78));
	float mullions = max(mullion_l, mullion_r);
	col = mix(col, vec3(0.035, 0.045, 0.095), mullions * 0.28);

	// Finas marcas doradas de mira astronómica en las 4 esquinas
	vec2 corner_d = min(uv, vec2(1.0) - uv);
	float in_corner_box = step(corner_d.x, 0.055) * step(corner_d.y, 0.09);
	float arm_x = (1.0 - smoothstep(0.001, 0.004, abs(corner_d.y - 0.024))) * step(corner_d.x, 0.052) * step(0.016, corner_d.x);
	float arm_y = (1.0 - smoothstep(0.0008, 0.0025, abs(corner_d.x - 0.016))) * step(corner_d.y, 0.085) * step(0.024, corner_d.y);
	float reticle = max(arm_x, arm_y) * in_corner_box;
	col = mix(col, astral_gold_color.rgb * 1.15, reticle * 0.62);

	// Gradiente atmosférico inferior para fundir el cristal con el antepecho del deck + viñeta fina
	float bottom_mist = 1.0 - smoothstep(0.78, 0.98, uv.y);
	col = mix(vec3(0.035, 0.055, 0.12), col, bottom_mist);
	vec2 edge_d = min(uv, vec2(1.0) - uv);
	float edge_mask = 1.0 - smoothstep(0.0, 0.045, min(edge_d.x, edge_d.y));
	col = mix(col, glass_edge_tint.rgb * 0.40, edge_mask * 0.50);

	// Pulso de barrido al re-sintonizar semilla del Cosmos
	if (retune_flash > 0.001) {
		float scan_y = 1.0 - retune_flash;
		float beam = 1.0 - smoothstep(0.0, 0.16, abs(uv.y - scan_y));
		col += retune_color.rgb * (beam * retune_flash * 1.65 + retune_flash * 0.25);
	}

	ALBEDO = col;
}
