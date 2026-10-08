shader_type canvas_item;
render_mode unshaded;

uniform vec2 u_size = vec2(100.0, 40.0);
// Per-side quad padding (left, right, top, bottom) that holds the shadow.
uniform vec4 u_pad = vec4(0.0);
uniform vec4 u_corner_radius = vec4(0.0);
uniform vec4 u_border_widths = vec4(0.0);
uniform vec4 u_shadow = vec4(0.0);
uniform float u_shadow_blur = -1.0;
uniform vec2 u_shadow_offset = vec2(0.0);
uniform float u_aa = 1.0;

uniform int u_fill_mode = 0;
uniform vec4 u_fill_a : source_color = vec4(1.0);
uniform vec4 u_fill_b : source_color = vec4(0.0);
uniform vec2 u_grad_p0 = vec2(0.0, 0.5);
uniform vec2 u_grad_p1 = vec2(1.0, 0.5);
uniform vec2 u_grad_offsets = vec2(0.0, 1.0);

uniform int u_border_mode = 0;
uniform vec4 u_border_a : source_color = vec4(0.0);
uniform vec4 u_border_b : source_color = vec4(0.0);
uniform vec2 u_border_p0 = vec2(0.0, 0.5);
uniform vec2 u_border_p1 = vec2(1.0, 0.5);
uniform vec4 u_border_left : source_color = vec4(0.0);
uniform vec4 u_border_right : source_color = vec4(0.0);
uniform vec4 u_border_top : source_color = vec4(0.0);
uniform vec4 u_border_bottom : source_color = vec4(0.0);

uniform vec4 u_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.4);
// Sampler wrap and filter are fixed when the shader compiles, so runtime control
// needs one variant per filter plus manual clamping for the no-repeat case.
uniform sampler2D u_tex : source_color, hint_default_white, repeat_enable, filter_linear;
uniform sampler2D u_tex_nearest : source_color, hint_default_white, repeat_enable, filter_nearest;
uniform float u_fill_nearest = 0.0;
uniform float u_fill_repeat = 0.0;
uniform float u_fill_natural = 0.0;
uniform float u_fill_fade = 1.0;
uniform vec2 u_fill_scroll = vec2(0.0);
uniform vec4 u_fill_tint : source_color = vec4(1.0);
uniform vec2 u_fill_scale = vec2(0.0);
uniform float u_fill_aspect = 0.0;

const float EPS = 0.0001;

const int CLIP_MAX = 32;
uniform vec2 u_clip[CLIP_MAX];
uniform int u_clip_count = 0;



// How far past each edge the point sits, measured from the corner circle's centre, with
// that corner's radius in z. Its two components also name the side a point belongs to:
// the larger one wins, which splits every corner down its 45-degree diagonal.
vec3 box_q(vec2 p, vec2 b, vec4 r) {
	r.xy = (p.x > 0.0) ? r.xy : r.zw;
	r.x = (p.y > 0.0) ? r.x : r.y;
	return vec3(abs(p) - b + r.x, r.x);
}


float sd_box(vec3 q) {
	return min(max(q.x, q.y), 0.0) + length(max(q.xy, vec2(0.0))) - q.z;
}


vec4 sample_gradient(vec4 ca, vec4 cb, vec2 offsets, float t) {
	float span = max(offsets.y - offsets.x, EPS);
	float k = clamp((t - offsets.x) / span, 0.0, 1.0);
	return mix(ca, cb, k);
}


// Signed distance to the clip polygon, in panel-local pixels. Points arrive normalised to
// the panel rect so the shape tracks resizes; negative is inside.
float clip_sd(vec2 pt, vec2 full) {
	vec2 first = (u_clip[0] - 0.5) * full;
	float d = dot(pt - first, pt - first);
	float s = 1.0;
	for (int i = 0; i < CLIP_MAX; i++) {
		if (i >= u_clip_count) {
			break;
		}
		int j = (i == 0) ? u_clip_count - 1 : i - 1;
		vec2 vi = (u_clip[i] - 0.5) * full;
		vec2 vj = (u_clip[j] - 0.5) * full;
		vec2 e = vj - vi;
		vec2 w = pt - vi;
		vec2 b = w - e * clamp(dot(w, e) / max(dot(e, e), EPS), 0.0, 1.0);
		d = min(d, dot(b, b));
		bvec3 c = bvec3(pt.y >= vi.y, pt.y < vj.y, e.x * w.y > e.y * w.x);
		if (all(c) || all(not(c))) {
			s = -s;
		}
	}
	return s * sqrt(d);
}


void fragment() {
	vec2 half_size = u_size * 0.5 - vec2(u_pad.x + u_pad.y, u_pad.z + u_pad.w) * 0.5;
	// Uneven padding pushes the panel off the quad's centre; p stays panel-relative.
	vec2 p = (UV - 0.5) * u_size - vec2(u_pad.x - u_pad.y, u_pad.z - u_pad.w) * 0.5;
	
	vec2 full = half_size * 2.0;
	vec4 cr = u_corner_radius;
	// Radii arrive as (top-left, top-right, bottom-left, bottom-right), so each edge is
	// clamped by the two corners that actually share it, then reordered for box_q, which
	// wants (bottom-right, top-right, bottom-left, top-left) on Godot's y-down canvas.
	float fit = min(1.0, min(
		min(full.x / max(cr.x + cr.y, EPS), full.x / max(cr.z + cr.w, EPS)),
		min(full.y / max(cr.x + cr.z, EPS), full.y / max(cr.y + cr.w, EPS))));
	cr *= fit;
	vec4 ordered_radius = vec4(cr.w, cr.y, cr.z, cr.x);
	
	vec3 q_outer = box_q(p, half_size, ordered_radius);
	float d_outer = sd_box(q_outer);
	// Width the edge blend by the pixel footprint of p, not by fwidth of the distance
	// field: sd_box's min(max(q.x, q.y), 0.0) kinks where q.x == q.y, i.e. along each
	// corner's inward diagonal, so fwidth(d_outer) doubles there and leaves a seam.
	// p is affine in UV, so its derivatives are constant and cannot spike.
	float aa = max(u_aa * 0.5 * (fwidth(p.x) + fwidth(p.y)), EPS);
	
	vec2 inner_center = vec2((u_border_widths.x - u_border_widths.y) * 0.5,
							 (u_border_widths.z - u_border_widths.w) * 0.5);
	vec2 inner_half = max(half_size - vec2((u_border_widths.x + u_border_widths.y) * 0.5,
										   (u_border_widths.z + u_border_widths.w) * 0.5), vec2(EPS));
	vec2 inner_full = inner_half * 2.0;
	// Each corner's inner radius drops by the mean of the two border widths meeting there.
	// Reusing the outer radius only shifted the arc's centre, leaving the ring wider along
	// the diagonal than on the sides; shrinking the radius keeps the arcs concentric.
	vec4 corner_bw = vec4(
		(u_border_widths.x + u_border_widths.z) * 0.5,
		(u_border_widths.y + u_border_widths.z) * 0.5,
		(u_border_widths.x + u_border_widths.w) * 0.5,
		(u_border_widths.y + u_border_widths.w) * 0.5);
	vec4 icr = max(cr - corner_bw, vec4(0.0));
	float ifit = min(1.0, min(
		min(inner_full.x / max(icr.x + icr.y, EPS), inner_full.x / max(icr.z + icr.w, EPS)),
		min(inner_full.y / max(icr.x + icr.z, EPS), inner_full.y / max(icr.y + icr.w, EPS))));
	icr *= ifit;
	vec4 inner_radius = vec4(icr.w, icr.y, icr.z, icr.x);
	float d_inner = sd_box(box_q(p - inner_center, inner_half, inner_radius));
	
	vec4 fill_col;
	if (u_fill_mode == 1) {
		vec2 dir = u_grad_p1 - u_grad_p0;
		float denom = max(dot(dir, dir), EPS);
		float t = clamp(dot(UV - u_grad_p0, dir) / denom, 0.0, 1.0);
		fill_col = sample_gradient(u_fill_a, u_fill_b, u_grad_offsets, t);
	} else if (u_fill_mode == 2) {
		float t = clamp(length(UV - u_grad_p0)
			/ max(length(u_grad_p1 - u_grad_p0), EPS), 0.0, 1.0);
		fill_col = sample_gradient(u_fill_a, u_fill_b, u_grad_offsets, t);
	} else if (u_fill_mode == 3) {
		// Work in panel pixels, then divide by the tile size: the panel itself when
		// stretching (scale left at 0), or the texture's own size times the scale when
		// tiling. Scroll stays panel pixels per second either way.
		// p runs -half_size..+half_size across the panel, so this is panel-local. UV spans
		// the padded quad instead, so UV * full only agrees with it when u_pad is zero -
		// with a shadow it shifts the fill and puts the contain bars in the wrong place.
		vec2 px = p + half_size - u_fill_scroll * TIME;
		// Only the sampler in use holds the texture; the other is left unbound, because
		// GLES3 stores filter and repeat on the texture object, so binding one texture to
		// both would let the second bind overwrite the first's filtering.
		bool nearest = u_fill_nearest > 0.5;
		vec2 tex_size = nearest ? vec2(textureSize(u_tex_nearest, 0)) : vec2(textureSize(u_tex, 0));
		vec2 tile = full;
		bool contain = false;
		if (u_fill_scale.x > EPS && u_fill_scale.y > EPS) {
			tile = u_fill_scale * tex_size;
		} else if (u_fill_natural > 0.5) {
			// repeat tiles at the texture's own size, as background-repeat does; stretching
			// one copy over the panel leaves nothing to visibly repeat.
			tile = tex_size;
		} else if (u_fill_aspect > 0.5) {
			// Contain: grow the tile to the panel on whichever axis runs out first, keeping
			// the texture's own ratio, then centre what is left over.
			float panel_ar = full.x / max(full.y, EPS);
			float tex_ar = tex_size.x / max(tex_size.y, EPS);
			tile = (tex_ar > panel_ar) ? vec2(full.x, full.x / tex_ar) : vec2(full.y * tex_ar, full.y);
			px -= (full - tile) * 0.5;
			contain = true;
		}
		vec2 uv = px / max(tile, vec2(EPS));
		if (u_fill_repeat < 0.5) {
			uv = clamp(uv, vec2(0.0), vec2(1.0));
		}
		vec4 img = (nearest ? texture(u_tex_nearest, uv) : texture(u_tex, uv)) * u_fill_tint;
		// Fitting the texture inside the panel leaves bars around it, and those have to be
		// empty rather than a clamped or tiled continuation of the edge pixels.
		if (contain && (px.x < 0.0 || px.y < 0.0 || px.x > tile.x || px.y > tile.y)) {
			img = vec4(0.0);
		}
		img.a *= u_fill_fade;
		// bg_color sits underneath, so a texture with alpha shows the colour through.
		float img_a = img.a + u_fill_a.a * (1.0 - img.a);
		fill_col = vec4(img_a > EPS
			? (img.rgb * img.a + u_fill_a.rgb * u_fill_a.a * (1.0 - img.a)) / img_a
			: img.rgb, img_a);
	} else {
		fill_col = u_fill_a;
	}
	
	vec4 border_col;
	if (u_border_mode == 1) {
		vec2 dir = u_border_p1 - u_border_p0;
		float denom = max(dot(dir, dir), EPS);
		float t = clamp(dot(UV - u_border_p0, dir) / denom, 0.0, 1.0);
		border_col = mix(u_border_a, u_border_b, t);
	} else if (u_border_mode == 4) {
		border_col = (q_outer.x > q_outer.y)
			? (p.x < 0.0 ? u_border_left : u_border_right)
			: (p.y < 0.0 ? u_border_top : u_border_bottom);
	} else {
		border_col = u_border_a;
	}
	
	float fill_mask = 1.0 - smoothstep(-aa, aa, d_inner);
	float panel_mask = 1.0 - smoothstep(-aa, aa, d_outer);
	float border_mask = clamp(panel_mask - fill_mask, 0.0, 1.0);
	
	// Straight-alpha source-over throughout: the border sits on the fill, and both sit on
	// the shadow. Blending the layers by coverage alone would tint a see-through panel
	// with whatever is underneath it.
	float fill_a = fill_col.a * fill_mask;
	float border_a = border_col.a * border_mask;
	float panel_a = border_a + fill_a * (1.0 - border_a);
	vec3 panel_rgb = panel_a > EPS
		? (border_col.rgb * border_a + fill_col.rgb * fill_a * (1.0 - border_a)) / panel_a
		: fill_col.rgb;
	vec4 col = vec4(panel_rgb, panel_a);
	
	if (max(max(u_shadow.x, u_shadow.y), max(u_shadow.z, u_shadow.w)) > 0.5) {
		// The reach in the fragment's outward direction blends the two side extents that
		// meet at that corner, weighted by the squared direction so an even shadow keeps
		// its radius and a side left at 0 fades out instead of cutting off.
		vec2 sp = p - u_shadow_offset;
		vec3 q_shadow = box_q(sp, half_size, ordered_radius);
		float d_shadow = sd_box(q_shadow);
		vec2 outward = max(q_shadow.xy, vec2(0.0));
		vec2 dir = outward / max(length(outward), EPS);
		vec2 ext = vec2(sp.x < 0.0 ? u_shadow.x : u_shadow.y, sp.y < 0.0 ? u_shadow.z : u_shadow.w);
		float reach = dot(dir * dir, ext);
		// blur is the width of the fade at the shadow's outer edge, so 0 is a hard cut and
		// the -1 default reproduces the original fade across the whole reach.
		float blur = u_shadow_blur < 0.0 ? reach : u_shadow_blur;
		float fade_hi = max(reach, EPS);
		// Never let the fade collapse below a pixel: shadow_blur 0 means a crisp edge, not an
		// unantialiased step, which would stair-step along the shadow's whole outline.
		float fade_lo = fade_hi - max(blur, aa);
		float shadow_alpha = 1.0 - smoothstep(fade_lo, fade_hi, d_shadow);
		// (1.0 - panel_mask) already confines the shadow to the share of the pixel the panel
		// does not cover, so the two are disjoint and simply add. Folding it in with
		// source-over scaled the shadow by that coverage a second time, which punched a 25%
		// alpha notch along the whole outline - a hairline of background between the two.
		shadow_alpha *= u_shadow_color.a * (1.0 - panel_mask);
		float out_a = min(col.a + shadow_alpha, 1.0);
		col = vec4(out_a > EPS
			? (col.rgb * col.a + u_shadow_color.rgb * shadow_alpha) / out_a
			: col.rgb, out_a);
	}
	
	if (u_clip_count >= 3) {
		col.a *= 1.0 - smoothstep(-aa, aa, clip_sd(p, full));
	}
	
	COLOR = col;
}
