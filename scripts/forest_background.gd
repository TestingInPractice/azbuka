extends Control

@export var zoom := 1.0
@export var focus := Vector2(0.5, 0.5)

const DESIGN := Vector2(1080, 1920)

const SKY_TOP_LIGHT := Color("#FFD78C")
const SKY_BOT_LIGHT := Color("#A8D8EA")
const SKY_TOP_DARK := Color("#0B0B2A")
const SKY_BOT_DARK := Color("#1A1A4E")
const GROUND_LIGHT := Color("#4A7C3F")
const GROUND_DARK := Color("#1A3A1A")
const GROUND2_LIGHT := Color("#3D6B35")
const TREE_TRUNK := Color("#5C3A1E")
const TREE_BG := Color("#3A6B32")
const TREE_FG := Color("#4A8C3F")
const TREE_DARK_BG := Color("#1A3A1A")
const TREE_DARK_FG := Color("#2D5A27")
const LAKE_LIGHT := Color("#5BA3D9")
const LAKE_SHORE_LIGHT := Color("#7AB8D9")
const LAKE_DARK := Color("#1A3050")
const LAKE_SHORE_DARK := Color("#2A4560")
const HUT_WALL := Color("#8B5E3C")
const HUT_ROOF := Color("#A0522D")
const HUT_DOOR := Color("#5C3A1E")
const HUT_WINDOW := Color("#FFE4A0")
const HUT_LEG := Color("#5C3A1E")
const HUT_DARK_WALL := Color("#3A2A1A")
const HUT_DARK_ROOF := Color("#4A3020")
const HUT_DARK_DOOR := Color("#2A1A0E")
const HUT_DARK_WINDOW := Color("#2A2A40")
const HUT_DARK_LEG := Color("#2A1A0E")
const STUMP_TOP_LIGHT := Color("#8B6B4A")
const STUMP_SIDE_LIGHT := Color("#6B4226")
const STUMP_TOP_DARK := Color("#4A3520")
const STUMP_SIDE_DARK := Color("#3A2515")
const ROCK_LIGHT := Color("#909090")
const ROCK_DARK := Color("#505050")
const MUSHROOM_CAP := Color("#CC4444")
const MUSHROOM_CAP_DOT := Color("#FFFFFF")
const MUSHROOM_STEM := Color("#E8D8C8")
const MUSHROOM_DARK_CAP := Color("#662222")
const MUSHROOM_DARK_STEM := Color("#4A3A2A")

var _size := DESIGN

func _ready():
	_size = size
	resized.connect(_on_resized)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	queue_redraw()

func _on_resized():
	_size = size
	queue_redraw()

func _on_theme_changed(_name: String):
	queue_redraw()

func _draw():
	var is_dark = ThemeManager.current_theme == "dark"
	var aspect = _size.x / _size.y
	var vw = 1.0 / zoom
	var vh = vw / aspect
	var left = focus.x - vw * 0.5
	var top = focus.y - vh * 0.5

	var w = _size.x
	var h = _size.y

	var sx = func(nx): return (nx - left) / vw * w
	var sy = func(ny): return (ny - top) / vh * h
	var sz = func(ns): return ns / vw * w

	var p = func(nx, ny): return Vector2(sx.call(nx), sy.call(ny))
	var pw = func(nx, ny, nw, nh): return Rect2(sx.call(nx), sy.call(ny), sz.call(nw), sz.call(nh))

	_draw_sky(is_dark, p, pw, w, h)
	_draw_trees(is_dark, p, pw, sz, true)
	_draw_lake(is_dark, p, pw, sz)
	_draw_hut(is_dark, p, pw, sz)
	_draw_objects(is_dark, p, pw, sz)
	_draw_trees(is_dark, p, pw, sz, false)

func _draw_sky(is_dark: bool, p: Callable, pw: Callable, w: float, h: float):
	var top_c = SKY_TOP_LIGHT if not is_dark else SKY_TOP_DARK
	var bot_c = SKY_BOT_LIGHT if not is_dark else SKY_BOT_DARK
	var bands = 24
	var band_h = 0.65 / bands
	for i in range(bands):
		var t = float(i) / float(bands - 1)
		var color = top_c.lerp(bot_c, t)
		draw_rect(pw.call(0, i * band_h, 1, band_h + 0.001), color)

	var gnd = GROUND_LIGHT if not is_dark else GROUND_DARK
	var gnd2 = GROUND2_LIGHT if not is_dark else (GROUND_DARK.darkened(0.15))
	draw_rect(pw.call(0, 0.65, 1, 0.25), gnd)
	draw_rect(pw.call(0, 0.90, 1, 0.1), gnd2)

func _draw_trees(is_dark: bool, p: Callable, pw: Callable, sz: Callable, background: bool):
	if background:
		var trees = [
			[0.12, 0.40, 0.14, 0.35],
			[0.88, 0.38, 0.16, 0.38],
			[0.25, 0.42, 0.10, 0.28],
			[0.78, 0.44, 0.12, 0.30],
		]
		var c = TREE_BG if not is_dark else TREE_DARK_BG
		for t in trees:
			_draw_tree_shape(p, sz, t[0], t[1], t[2], t[3], c)
	else:
		var trees = [
			[0.05, 0.45, 0.20, 0.55],
			[0.95, 0.50, 0.18, 0.50],
			[0.02, 0.55, 0.14, 0.40],
			[0.98, 0.60, 0.15, 0.45],
		]
		var c = TREE_FG if not is_dark else TREE_DARK_FG
		for t in trees:
			_draw_tree_shape(p, sz, t[0], t[1], t[2], t[3], c)

func _draw_tree_shape(p: Callable, sz: Callable, nx: float, ny: float, nw: float, nh: float, color: Color):
	var cx = nx
	var by = ny
	var ty = ny - nh
	var hw = nw * 0.5

	var trunk_w = nw * 0.08
	var trunk_h = nh * 0.15
	draw_rect(Rect2(p.call(cx - trunk_w * 0.5, by), Vector2(sz.call(trunk_w), sz.call(trunk_h))), TREE_TRUNK)

	var layers = 3
	for i in range(layers):
		var t = float(i) / float(layers)
		var ly = ty + t * nh * 0.6
		var lh = nh * 0.35 / layers * 1.5
		var lw = hw * (1.0 - t * 0.3)
		var pts = PackedVector2Array([
			p.call(cx, ly),
			p.call(cx + lw, ly + lh),
			p.call(cx - lw, ly + lh),
		])
		var darker = color.darkened(t * 0.2)
		draw_colored_polygon(pts, darker)

func _draw_lake(is_dark: bool, p: Callable, pw: Callable, sz: Callable):
	if focus.y > 0.75 and zoom > 1.2:
		return
	var lc = LAKE_LIGHT if not is_dark else LAKE_DARK
	var sc = LAKE_SHORE_LIGHT if not is_dark else LAKE_SHORE_DARK
	var cx = 0.5
	var cy = 0.60
	var rx = 0.18
	var ry = 0.06

	var segs = 32

	var lake_pts = PackedVector2Array()
	for i in range(segs + 1):
		var a = float(i) / float(segs) * TAU
		lake_pts.append(p.call(cx + cos(a) * rx, cy + sin(a) * ry))
	draw_colored_polygon(lake_pts, lc)

	for i in range(segs):
		var a1 = float(i) / float(segs) * TAU
		var a2 = float(i + 1) / float(segs) * TAU
		var inner = p.call(cx + cos(a1) * rx, cy + sin(a1) * ry)
		var outer = p.call(cx + cos(a1) * (rx + 0.015), cy + sin(a1) * (ry + 0.004))
		var outer2 = p.call(cx + cos(a2) * (rx + 0.015), cy + sin(a2) * (ry + 0.004))
		var inner2 = p.call(cx + cos(a2) * rx, cy + sin(a2) * ry)
		var strip = PackedVector2Array([inner, outer, outer2, inner2])
		draw_colored_polygon(strip, sc)

func _draw_hut(is_dark: bool, p: Callable, pw: Callable, sz: Callable):
	var wall_c = HUT_WALL if not is_dark else HUT_DARK_WALL
	var roof_c = HUT_ROOF if not is_dark else HUT_DARK_ROOF
	var door_c = HUT_DOOR if not is_dark else HUT_DARK_DOOR
	var win_c = HUT_WINDOW if not is_dark else HUT_DARK_WINDOW
	var leg_c = HUT_LEG if not is_dark else HUT_DARK_LEG

	var cx = 0.74
	var by = 0.64
	var wd = 0.16
	var ht = 0.14

	var wall_r = pw.call(cx - wd * 0.5, by - ht, wd, ht)
	draw_rect(wall_r, wall_c)

	var roof_pts = PackedVector2Array([
		p.call(cx - wd * 0.55, by - ht),
		p.call(cx, by - ht - wd * 0.3),
		p.call(cx + wd * 0.55, by - ht),
	])
	draw_colored_polygon(roof_pts, roof_c)

	var door_w = wd * 0.3
	var door_h = ht * 0.55
	draw_rect(Rect2(p.call(cx - door_w * 0.5, by - door_h), Vector2(sz.call(door_w), sz.call(door_h))), door_c)

	var win_w = wd * 0.2
	var win_h = ht * 0.2
	draw_rect(Rect2(p.call(cx + wd * 0.1, by - ht * 0.75), Vector2(sz.call(win_w), sz.call(win_h))), win_c)

	var leg_w = wd * 0.04
	var leg_h = ht * 0.4
	var leg1 = Rect2(p.call(cx - wd * 0.35 - leg_w * 0.5, by), Vector2(sz.call(leg_w), sz.call(leg_h)))
	var leg2 = Rect2(p.call(cx + wd * 0.35 - leg_w * 0.5, by), Vector2(sz.call(leg_w), sz.call(leg_h)))
	draw_rect(leg1, leg_c)
	draw_rect(leg2, leg_c)

	var foot_r = wd * 0.04
	draw_circle(p.call(cx - wd * 0.35, by + leg_h), sz.call(foot_r), leg_c)
	draw_circle(p.call(cx + wd * 0.35, by + leg_h), sz.call(foot_r), leg_c)

func _draw_objects(is_dark: bool, p: Callable, pw: Callable, sz: Callable):
	var st_top = STUMP_TOP_LIGHT if not is_dark else STUMP_TOP_DARK
	var st_side = STUMP_SIDE_LIGHT if not is_dark else STUMP_SIDE_DARK
	var r_c = ROCK_LIGHT if not is_dark else ROCK_DARK
	var mc = MUSHROOM_CAP if not is_dark else MUSHROOM_DARK_CAP
	var ms = MUSHROOM_STEM if not is_dark else MUSHROOM_DARK_STEM

	_draw_stump(p, pw, sz, 0.22, 0.72, 0.10, 0.08, st_side, st_top)

	for i in 3:
		var rnx = 0.55 + i * 0.08
		var rny = 0.73 + (i % 2) * 0.03
		var rr = 0.025 + (i % 2) * 0.01
		draw_circle(p.call(rnx, rny), sz.call(rr), r_c)

	_draw_mushroom(p, pw, sz, 0.12, 0.70, mc, ms)
	_draw_mushroom(p, pw, sz, 0.93, 0.74, mc, ms)

func _draw_stump(p: Callable, pw: Callable, sz: Callable, nx: float, ny: float, nw: float, nh: float, side: Color, top: Color):
	draw_rect(Rect2(p.call(nx - nw * 0.5, ny - nh), Vector2(sz.call(nw), sz.call(nh))), side)

	draw_circle(p.call(nx, ny - nh), sz.call(nw * 0.5), top)

	draw_circle(p.call(nx, ny - nh), sz.call(nw * 0.5) - sz.call(0.005), side, false)

	var rings = 2
	for i in range(rings):
		var r = nw * 0.5 * (0.5 - i * 0.15)
		draw_arc(p.call(nx, ny - nh), sz.call(r), 0, TAU, 16, side.darkened(0.15), sz.call(0.004), true)

func _draw_mushroom(p: Callable, pw: Callable, sz: Callable, nx: float, ny: float, cap: Color, stem: Color):
	var stem_w = 0.025
	var stem_h = 0.05
	draw_rect(Rect2(p.call(nx - stem_w * 0.5, ny - stem_h), Vector2(sz.call(stem_w), sz.call(stem_h))), stem)

	var cap_w = 0.06
	var cap_h = 0.035
	var cap_pts = PackedVector2Array([
		p.call(nx - cap_w, ny - stem_h),
		p.call(nx, ny - stem_h - cap_h),
		p.call(nx + cap_w, ny - stem_h),
	])
	draw_colored_polygon(cap_pts, cap)

	var dot_r = cap_w * 0.12
	draw_circle(p.call(nx - cap_w * 0.4, ny - stem_h - cap_h * 0.3), sz.call(dot_r), MUSHROOM_CAP_DOT)
	draw_circle(p.call(nx + cap_w * 0.3, ny - stem_h - cap_h * 0.5), sz.call(dot_r * 0.8), MUSHROOM_CAP_DOT)
