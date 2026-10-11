extends Node
## The Last Knight - scene builder
## สร้าง SpriteFrames, TileSet, Prefab และด่านทั้ง 4 จากไฟล์ tools/levels/*.txt
##
##   Godot --headless --path . res://tools/build_game.tscn
##
## (รัน tools/make_assets.py และ tools/make_levels.py ก่อน)

const LK := "res://Assets/LastKnight/"
const PF := "res://Scenes/Prefabs/LastKnight/"
const ACT := "res://Scenes/Actors/"
const T := 32  # tile size

const L_WALL := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_ITEM := 8

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2024
	DirAccess.make_dir_recursive_absolute(LK + "frames")
	build_frames()
	build_tileset()
	build_prefabs()
	for i in [4, 3, 2, 1]:
		build_level(i)
	print("BUILD OK")
	get_tree().quit()


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func save_scene(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed " + path)
	err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("save failed " + path)
	root.free()
	print("  saved ", path)


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		if c.owner == null:
			c.owner = root
		# keep nodes of instanced sub-scenes owned by their scene
		if c.scene_file_path == "":
			_own(c, root)


func add(parent: Node, node: Node, name: String = "") -> Node:
	if name != "":
		node.name = name
	parent.add_child(node)
	return node


func tex(path: String) -> Texture2D:
	return load(LK + path)


func sprite(texture_path: String, pos := Vector2.ZERO, bottom := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(texture_path)
	s.position = pos
	if bottom:
		s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	return s


func rect_shape(size: Vector2, pos := Vector2.ZERO) -> CollisionShape2D:
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	c.position = pos
	return c


func circle_shape(radius: float, pos := Vector2.ZERO) -> CollisionShape2D:
	var c := CollisionShape2D.new()
	var r := CircleShape2D.new()
	r.radius = radius
	c.shape = r
	c.position = pos
	return c


func capsule_shape(radius: float, height: float, pos := Vector2.ZERO, rot := 0.0) -> CollisionShape2D:
	var c := CollisionShape2D.new()
	var r := CapsuleShape2D.new()
	r.radius = radius
	r.height = height
	c.shape = r
	c.position = pos
	c.rotation = rot
	return c


func frames(texture_path: String, cw: int, ch: int, anims: Array) -> SpriteFrames:
	# anims: [name, row, first, count, fps, loop]
	var t := tex(texture_path)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[4])
		sf.set_animation_loop(a[0], a[5])
		for i in a[3]:
			var at := AtlasTexture.new()
			at.atlas = t
			at.region = Rect2((a[2] + i) * cw, a[1] * ch, cw, ch)
			sf.add_frame(a[0], at)
	return sf


func save_frames(sf: SpriteFrames, name: String) -> void:
	ResourceSaver.save(sf, LK + "frames/" + name + ".tres")


func anim_sprite(frames_name: String, anim: String, pos := Vector2.ZERO) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = load(LK + "frames/" + frames_name + ".tres")
	a.animation = anim
	a.autoplay = anim
	a.position = pos
	return a


func gradient(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	return g


func animation_player(anims: Dictionary, autoplay := "") -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	for k in anims:
		lib.add_animation(k, anims[k])
	ap.add_animation_library("", lib)
	if autoplay != "":
		ap.autoplay = autoplay
	return ap


func value_track(anim: Animation, path: String, keys: Array, discrete := false, trans := 1.0) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, path)
	if discrete:
		anim.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	for k in keys:
		var idx := anim.track_insert_key(t, k[0], k[1])
		anim.track_set_key_transition(t, idx, trans)


func trap_body(body: CollisionObject2D) -> CollisionObject2D:
	body.collision_layer = L_ITEM
	body.collision_mask = 0
	body.add_to_group("Traps", true)
	return body


# ---------------------------------------------------------------------------
# SpriteFrames
# ---------------------------------------------------------------------------
func build_frames() -> void:
	print("frames")
	var cw := 224
	var ch := 192
	var hero := [
		["idle", 0, 0, 4, 7, true],
		["run", 1, 0, 8, 13, true],
		["attack", 2, 0, 8, 24, false],
		["jump", 3, 2, 4, 12, false],
		["fall", 3, 7, 5, 10, true],
		["dead", 4, 0, 8, 10, false],
	]
	save_frames(frames("characters/knight.png", cw, ch, hero), "knight_frames")
	var undead := [
		["idle", 0, 0, 4, 5, true],
		["walk", 1, 0, 8, 7, true],
		["attack", 2, 0, 8, 14, true],
		["hurt", 4, 0, 2, 8, false],
	]
	save_frames(frames("characters/zombie.png", cw, ch, undead), "zombie_frames")
	save_frames(frames("characters/necro_knight.png", cw, ch, undead), "necro_frames")
	save_frames(frames("characters/zombie_boar.png", 96, 64, [
		["walk", 0, 0, 6, 12, true], ["hurt", 1, 0, 4, 12, false]]), "boar_frames")
	save_frames(frames("characters/ghost_wasp.png", 128, 128, [
		["walk", 0, 0, 4, 12, true], ["hurt", 1, 0, 4, 12, false]]), "wasp_frames")
	save_frames(frames("props/coin.png", 36, 36, [["spin", 0, 0, 6, 10, true]]), "coin_frames")
	save_frames(frames("props/portal.png", 80, 80, [["swirl", 0, 0, 6, 10, true]]), "portal_frames")
	save_frames(frames("props/saw.png", 64, 64, [["spin", 0, 0, 4, 20, true]]), "saw_frames")
	save_frames(frames("props/spring.png", 32, 32, [
		["idle", 0, 0, 1, 1, false], ["boing", 0, 1, 3, 14, false]]), "spring_frames")
	save_frames(frames("props/checkpoint.png", 32, 64, [
		["idle", 0, 0, 1, 1, false], ["active", 0, 1, 2, 4, true]]), "checkpoint_frames")
	save_frames(frames("props/slash.png", 64, 80, [["default", 0, 0, 3, 14, false]]), "slash_frames")


# ---------------------------------------------------------------------------
# TileSet: source 0 = forest tiles, source 1 = cursed (night) tiles
# ---------------------------------------------------------------------------
const SOLID_TILES := [
	# grass block cols 0..4 rows 1..4, stone block rows 6..9, castle bricks
	[0, 1], [1, 1], [2, 1], [3, 1], [4, 1],
	[0, 2], [1, 2], [2, 2], [3, 2], [4, 2],
	[0, 3], [1, 3], [2, 3], [3, 3], [4, 3],
	[0, 4], [1, 4], [2, 4], [3, 4], [4, 4],
	[0, 6], [1, 6], [2, 6], [3, 6], [4, 6],
	[0, 7], [1, 7], [2, 7], [3, 7], [4, 7],
	[0, 8], [1, 8], [2, 8], [3, 8], [4, 8],
	[0, 9], [1, 9], [2, 9], [3, 9], [4, 9],
	[10, 12], [11, 12], [12, 12], [10, 13], [11, 13], [12, 13],
]
const PLANK_TILES := [[5, 6], [6, 6], [7, 6]]
const DECO_TILES := [
	[0, 0], [1, 0], [2, 0], [3, 0], [4, 0],
	[0, 5], [1, 5], [2, 5], [3, 5], [4, 5],
	[6, 19], [7, 19], [8, 19], [9, 19], [6, 20], [7, 20], [8, 20], [9, 20],
]


func build_tileset() -> void:
	print("tileset")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, L_WALL)
	ts.set_physics_layer_collision_mask(0, 0)
	var h := T / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var plank := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 10), Vector2(-h, -h + 10)])
	for src_id in 2:
		var src := TileSetAtlasSource.new()
		src.texture = tex("tiles/forest_tiles.png" if src_id == 0 else "tiles/cursed_tiles.png")
		src.texture_region_size = Vector2i(T, T)
		ts.add_source(src, src_id)
		for c in SOLID_TILES + PLANK_TILES + DECO_TILES:
			var coord := Vector2i(c[0], c[1])
			src.create_tile(coord)
			var data := src.get_tile_data(coord, 0)
			if c in SOLID_TILES:
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, full)
			elif c in PLANK_TILES:
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, plank)
				data.set_collision_polygon_one_way(0, 0, true)
	ResourceSaver.save(ts, LK + "last_knight_tileset.tres")


# ---------------------------------------------------------------------------
# Prefabs
# ---------------------------------------------------------------------------
func build_prefabs() -> void:
	print("prefabs")
	DirAccess.make_dir_recursive_absolute(PF)
	build_sword_wave()
	build_dark_orb()
	build_enemies()
	build_traps()
	build_platforms()
	build_items()


func build_sword_wave() -> void:
	var b := RigidBody2D.new()
	b.name = "SwordWave"
	b.add_to_group("Bullet", true)
	b.collision_layer = L_PLAYER
	b.collision_mask = L_WALL
	b.gravity_scale = 0
	b.lock_rotation = true
	b.contact_monitor = true
	b.max_contacts_reported = 2
	b.set_script(load("res://Scenes/Prefabs/sword_wave.gd"))
	add(b, circle_shape(20), "CollisionShape2D")
	var s := anim_sprite("slash_frames", "default")
	s.autoplay = ""
	s.scale = Vector2(1.2, 1.2)
	add(b, s, "Sprite")
	var p := CPUParticles2D.new()
	p.amount = 12
	p.lifetime = 0.3
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(6, 28)
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2
	p.scale_amount_max = 4
	p.color = Color(0.7, 0.9, 1, 0.8)
	add(b, p, "Trail")
	b.body_entered.connect(Callable(b, "_on_body_entered"), CONNECT_PERSIST)
	save_scene(b, "res://Scenes/Prefabs/sword_wave.tscn")


func build_dark_orb() -> void:
	var a := Area2D.new()
	a.name = "DarkOrb"
	a.collision_layer = L_ENEMY
	a.collision_mask = L_WALL | L_PLAYER
	a.set_script(load(PF + "dark_orb.gd"))
	add(a, circle_shape(14), "CollisionShape2D")
	var s := Sprite2D.new()
	s.texture = load("res://Assets/Spritesheet/bullet.png")
	s.scale = Vector2(0.12, 0.12)
	s.modulate = Color(0.75, 0.3, 1.0)
	add(a, s, "Sprite")
	var p := CPUParticles2D.new()
	p.amount = 20
	p.lifetime = 0.5
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 3
	p.scale_amount_max = 7
	p.color_ramp = gradient([Color(0.8, 0.3, 1, 0.9), Color(0.2, 0, 0.4, 0)], [0, 1])
	add(a, p, "Trail")
	a.body_entered.connect(Callable(a, "_on_body_entered"), CONNECT_PERSIST)
	save_scene(a, PF + "dark_orb.tscn")


func explosion_particles(color: Color) -> GPUParticles2D:
	var gp := GPUParticles2D.new()
	gp.emitting = false
	gp.one_shot = true
	gp.amount = 32
	gp.lifetime = 0.7
	gp.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 180
	m.initial_velocity_min = 120
	m.initial_velocity_max = 320
	m.gravity = Vector3(0, 500, 0)
	m.scale_min = 4
	m.scale_max = 9
	var gt := GradientTexture1D.new()
	gt.gradient = gradient([color, color.darkened(0.6), Color(0, 0, 0, 0)], [0, 0.6, 1])
	m.color_ramp = gt
	gp.process_material = m
	gp.position = Vector2(0, -40)
	gp.z_index = 3
	return gp


func make_enemy(cfg: Dictionary) -> void:
	var base: PackedScene = load(ACT + "enemy.tscn")
	var e: Node = base.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	e.name = cfg.name
	e.set_script(load(cfg.get("script", ACT + "zombie.gd")))
	for k in cfg.props:
		e.set(k, cfg.props[k])
	var hgt: float = cfg.height
	var col: CollisionShape2D = e.get_node("CollisionShape2D")
	var cap := CapsuleShape2D.new()
	cap.radius = cfg.radius
	cap.height = max(hgt, cfg.radius * 2)
	col.shape = cap
	col.position = Vector2(0, -hgt / 2.0) if not cfg.get("flying", false) else Vector2.ZERO
	var hit: CollisionShape2D = e.get_node("HitArea/CollisionShape2D2")
	var cap2 := CapsuleShape2D.new()
	cap2.radius = cfg.radius + 4
	cap2.height = max(hgt + 6, cap2.radius * 2)
	hit.shape = cap2
	hit.position = col.position
	var ray_y: float = col.position.y
	for r in ["playerRayBack", "playerRayFront", "wallRay"]:
		e.get_node("Sprite/Ray/" + r).position.y = ray_y
	e.get_node("Sprite/Ray/playerRayBack").target_position = Vector2(cfg.get("sight", 260) * 0.6, 0)
	e.get_node("Sprite/Ray/playerRayFront").target_position = Vector2(-cfg.get("sight", 260), 0)
	e.get_node("Sprite/Ray/wallRay").target_position = Vector2(-cfg.radius - 12, 0)
	e.get_node("Sprite/Ray/floorRay").position = Vector2(-cfg.radius - 6, -16)
	e.get_node("Sprite/Ray/floorRay").target_position = Vector2(0, 30)
	var bar: ProgressBar = e.get_node("ProgressBar")
	var top: float = -hgt - 34 if not cfg.get("flying", false) else -hgt / 2.0 - 34
	var half: float = cfg.get("bar_w", 26)
	bar.offset_left = -half
	bar.offset_right = half
	bar.offset_top = top
	bar.offset_bottom = top + 12
	var lbl: Label = e.get_node("Label")
	lbl.offset_top = top - 26
	lbl.offset_bottom = top - 2
	lbl.add_theme_font_size_override("font_size", 12)
	var a := anim_sprite(cfg.frames, "walk")
	a.offset = cfg.offset
	a.flip_h = cfg.get("flip", false)
	a.scale = Vector2.ONE * cfg.get("scale", 1.0)
	if cfg.has("modulate"):
		a.modulate = cfg.modulate
	var spr: Node = e.get_node("Sprite")
	spr.add_child(a)
	spr.move_child(a, 0)
	a.name = "Anim"
	var ex := explosion_particles(cfg.get("blood", Color(0.45, 0.8, 0.3)))
	ex.position = col.position
	add(e, ex, "Explosion")
	save_scene(e, ACT + cfg.file)


func build_enemies() -> void:
	make_enemy({
		name = "Zombie", file = "zombie.tscn", frames = "zombie_frames", offset = Vector2(0, -72), flip = true,
		radius = 15.0, height = 84.0, sight = 300,
		props = {hp = 30, hp_max = 30, speed = 55.0, atk = 10, label = "ซอมบี้", type = 2, state = 2,
			chase_range = 280.0, attack_range = 36.0, patrol_wait_time = 3.0, score = 2, walk_anim_speed = 0.8},
	})
	make_enemy({
		name = "ZombieBoar", file = "zombie_boar.tscn", frames = "boar_frames", offset = Vector2(0, -32),
		radius = 18.0, height = 40.0, sight = 360, blood = Color(0.6, 0.75, 0.3),
		props = {hp = 40, hp_max = 40, speed = 110.0, atk = 15, label = "หมูป่าซอมบี้", type = 2, state = 2,
			chase_range = 360.0, attack_range = 30.0, patrol_wait_time = 2.5, score = 3, walk_anim_speed = 1.0},
	})
	make_enemy({
		name = "GhostWasp", file = "ghost_wasp.tscn", frames = "wasp_frames", offset = Vector2(0, 0),
		radius = 18.0, height = 36.0, flying = true, blood = Color(0.75, 0.5, 1.0),
		modulate = Color(1, 1, 1, 0.9),
		props = {hp = 20, hp_max = 20, speed = 130.0, atk = 10, label = "แตนผี", type = 1, state = 1,
			chase_range = 300.0, patrol_range = 220.0, score = 3, flying = true, gravity_scale = 0.0},
	})
	# boss uses the zombie grunt as summons and fires dark orbs
	make_enemy({
		name = "NecroKnight", file = "necro_knight.tscn", frames = "necro_frames", offset = Vector2(0, -72),
		flip = true, scale = 1.7, radius = 26.0, height = 140.0, sight = 520, bar_w = 70,
		blood = Color(0.7, 0.2, 1.0), script = ACT + "boss.gd",
		props = {hp = 220, hp_max = 220, speed = 70.0, atk = 20, label = "มอร์ธัส อัศวินเนโคร", type = 5,
			state = 2, chase_range = 500.0, attack_range = 300.0, attack_cooldown_time = 1.6,
			rest_hp_threshold = 50, regen_hp_per_second = 5.0, score = 50, knockback_force = 60.0,
			walk_anim_speed = 0.8, projectile_scene = load(PF + "dark_orb.tscn"),
			summon_scene = load(ACT + "zombie.tscn")},
	})
	# grave that keeps spawning zombies
	var sp: Node = (load(ACT + "enemy_spawn.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	sp.name = "ZombieGrave"
	var es: Array[PackedScene] = [load(ACT + "zombie.tscn")]
	var spd: Array[int] = [40, 55, 65]
	var rt: Array[int] = [6, 9]
	sp.enemy_scenes = es
	sp.speed_range = spd
	sp.respawn_time = rt
	sp.max_instance = 2
	add(sp, sprite("decor/tomb_round.png", Vector2(0, 0), true), "Tomb")
	var dirt := CPUParticles2D.new()
	dirt.amount = 6
	dirt.lifetime = 1.2
	dirt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dirt.emission_rect_extents = Vector2(20, 2)
	dirt.direction = Vector2(0, -1)
	dirt.initial_velocity_min = 10
	dirt.initial_velocity_max = 30
	dirt.gravity = Vector2(0, 20)
	dirt.color = Color(0.5, 0.9, 0.4, 0.6)
	dirt.scale_amount_min = 2
	dirt.scale_amount_max = 3
	add(sp, dirt, "Miasma")
	save_scene(sp, ACT + "zombie_grave.tscn")


func build_traps() -> void:
	# --- floor spikes
	var sb := trap_body(StaticBody2D.new())
	sb.name = "TrapSpikes"
	add(sb, sprite("props/spikes.png", Vector2.ZERO, true), "Sprite")
	add(sb, rect_shape(Vector2(26, 12), Vector2(0, -7)), "CollisionShape2D")
	save_scene(sb, PF + "trap_spikes.tscn")

	# --- spear: random delay, collision only while the spear is out
	var sp := Node2D.new()
	sp.name = "TrapSpear"
	sp.set_script(load(PF + "spear_trap.gd"))
	var body := trap_body(StaticBody2D.new())
	body.position = Vector2(0, 96)
	body.z_index = -1
	add(sp, body, "SpearBody")
	add(body, sprite("props/spear.png", Vector2(0, -48)), "Sprite")
	var cs := rect_shape(Vector2(10, 80), Vector2(0, -44))
	cs.disabled = true
	add(body, cs, "CollisionShape2D")
	add(sp, sprite("props/spear_base.png", Vector2(0, -6)), "Base")
	var push := Animation.new()
	push.length = 1.9
	value_track(push, "SpearBody:position", [[0.0, Vector2(0, 96)], [0.25, Vector2(0, 80)], [0.4, Vector2(0, 0)],
		[1.3, Vector2(0, 0)], [1.9, Vector2(0, 96)]])
	value_track(push, "SpearBody/CollisionShape2D:disabled", [[0.0, true], [0.35, false], [1.6, true]], true)
	add(sp, animation_player({"push": push}), "AnimationPlayer")
	save_scene(sp, PF + "trap_spear.tscn")

	# --- pendulum spike ball swinging from the ceiling
	var pd := Node2D.new()
	pd.name = "TrapPendulum"
	var arm := Node2D.new()
	add(pd, arm, "Arm")
	var length := 210.0
	var chain := Sprite2D.new()
	chain.texture = tex("props/chain.png")
	chain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	chain.region_enabled = true
	chain.region_rect = Rect2(0, 0, 12, length)
	chain.position = Vector2(0, length / 2)
	add(arm, chain, "Chain")
	var ball := trap_body(StaticBody2D.new())
	ball.position = Vector2(0, length)
	add(arm, ball, "Ball")
	add(ball, sprite("props/spike_ball.png"), "Sprite")
	add(ball, circle_shape(26), "CollisionShape2D")
	add(pd, sprite("props/anchor.png", Vector2(0, 6)), "Anchor")
	var swing := Animation.new()
	swing.length = 1.6
	swing.loop_mode = Animation.LOOP_PINGPONG
	value_track(swing, "Arm:rotation", [[0.0, -1.15], [1.6, 1.15]], false, -2.0)
	add(pd, animation_player({"swing": swing}, "swing"), "AnimationPlayer")
	save_scene(pd, PF + "trap_pendulum.tscn")

	# --- saw blades on a mover (horizontal & vertical)
	for v in [["trap_saw.tscn", Vector2(160, 0)], ["trap_saw_vertical.tscn", Vector2(0, -110)]]:
		var mv := Node2D.new()
		mv.name = "TrapSaw"
		mv.set_script(load(PF + "mover.gd"))
		mv.offset = v[1]
		mv.duration = 1.4
		mv.pause = 0.2
		var saw := trap_body(StaticBody2D.new())
		add(mv, saw, "Saw")
		var a := anim_sprite("saw_frames", "spin")
		a.set_script(load(PF + "spin.gd"))
		a.speed = 8.0
		a.scale = Vector2(1.2, 1.2)
		add(saw, a, "Sprite")
		add(saw, circle_shape(34), "CollisionShape2D")
		save_scene(mv, PF + v[0])

	# --- fire brazier
	var fb := trap_body(StaticBody2D.new())
	fb.name = "TrapFire"
	fb.set_script(load(PF + "fire_trap.gd"))
	add(fb, sprite("props/brazier.png", Vector2(0, -12)), "Brazier")
	var cs2 := rect_shape(Vector2(28, 120), Vector2(0, -84))
	cs2.disabled = true
	add(fb, cs2, "CollisionShape2D")
	var fl := CPUParticles2D.new()
	fl.position = Vector2(0, -24)
	fl.emitting = false
	fl.amount = 70
	fl.lifetime = 0.6
	fl.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fl.emission_rect_extents = Vector2(12, 2)
	fl.direction = Vector2(0, -1)
	fl.spread = 6
	fl.gravity = Vector2(0, -60)
	fl.initial_velocity_min = 180
	fl.initial_velocity_max = 260
	fl.scale_amount_min = 6
	fl.scale_amount_max = 12
	fl.color_ramp = gradient([Color(1, 1, 0.6), Color(1, 0.55, 0.1), Color(0.8, 0.1, 0.05, 0.6), Color(0.2, 0.2, 0.2, 0)],
		[0, 0.3, 0.7, 1])
	add(fb, fl, "Flame")
	var wn := CPUParticles2D.new()
	wn.position = Vector2(0, -24)
	wn.emitting = false
	wn.amount = 10
	wn.lifetime = 0.4
	wn.direction = Vector2(0, -1)
	wn.spread = 25
	wn.gravity = Vector2.ZERO
	wn.initial_velocity_min = 40
	wn.initial_velocity_max = 80
	wn.scale_amount_min = 2
	wn.scale_amount_max = 4
	wn.color = Color(1, 0.6, 0.2)
	add(fb, wn, "Warn")
	save_scene(fb, PF + "trap_fire.tscn")


func build_platforms() -> void:
	for v in [["moving_platform.tscn", "props/plank.png", Vector2(192, 0)],
			["elevator.tscn", "props/stone_ledge.png", Vector2(0, -224)]]:
		var mv := Node2D.new()
		mv.name = "MovingPlatform" if v[0] == "moving_platform.tscn" else "Elevator"
		mv.set_script(load(PF + "mover.gd"))
		mv.offset = v[2]
		mv.duration = 2.5
		mv.pause = 0.8
		var body := AnimatableBody2D.new()
		body.collision_layer = L_WALL
		body.collision_mask = 0
		add(mv, body, "Platform")
		add(body, sprite(v[1], Vector2(0, 16)), "Sprite")
		var cs := rect_shape(Vector2(96, 12), Vector2(0, 6))
		cs.one_way_collision = v[0] == "moving_platform.tscn"
		add(body, cs, "CollisionShape2D")
		save_scene(mv, PF + v[0])

	# jump pad
	var jp := Area2D.new()
	jp.name = "JumpPad"
	jp.collision_layer = 0
	jp.collision_mask = L_PLAYER
	jp.set_script(load(PF + "jump_pad.gd"))
	var sa := anim_sprite("spring_frames", "idle", Vector2(0, -24))
	sa.scale = Vector2(1.5, 1.5)
	add(jp, sa, "Sprite")
	add(jp, rect_shape(Vector2(40, 14), Vector2(0, -12)), "CollisionShape2D")
	jp.body_entered.connect(Callable(jp, "_on_body_entered"), CONNECT_PERSIST)
	save_scene(jp, PF + "jump_pad.tscn")

	# portal
	var po := Area2D.new()
	po.name = "Portal"
	po.collision_layer = 0
	po.collision_mask = L_PLAYER
	po.set_script(load(PF + "portal.gd"))
	var pa := anim_sprite("portal_frames", "swirl", Vector2(0, -60))
	pa.scale = Vector2(1.5, 1.5)
	add(po, pa, "Sprite")
	add(po, rect_shape(Vector2(36, 90), Vector2(0, -50)), "CollisionShape2D")
	var pp := CPUParticles2D.new()
	pp.position = Vector2(0, -60)
	pp.amount = 24
	pp.lifetime = 1.0
	pp.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	pp.emission_sphere_radius = 40
	pp.gravity = Vector2(0, -40)
	pp.scale_amount_min = 2
	pp.scale_amount_max = 4
	pp.color = Color(0.85, 0.5, 1, 0.8)
	add(po, pp, "Particles")
	po.body_entered.connect(Callable(po, "_on_body_entered"), CONNECT_PERSIST)
	po.body_exited.connect(Callable(po, "_on_body_exited"), CONNECT_PERSIST)
	save_scene(po, PF + "portal.tscn")

	# checkpoint banner
	var cp := Area2D.new()
	cp.name = "Checkpoint"
	cp.collision_layer = 0
	cp.collision_mask = L_PLAYER
	cp.set_script(load(PF + "checkpoint.gd"))
	var ca := anim_sprite("checkpoint_frames", "idle", Vector2(0, -48))
	ca.scale = Vector2(1.5, 1.5)
	add(cp, ca, "Sprite")
	add(cp, rect_shape(Vector2(40, 96), Vector2(0, -48)), "CollisionShape2D")
	var cpp := CPUParticles2D.new()
	cpp.position = Vector2(0, -60)
	cpp.emitting = false
	cpp.one_shot = true
	cpp.explosiveness = 0.9
	cpp.amount = 30
	cpp.lifetime = 1.0
	cpp.spread = 180
	cpp.initial_velocity_min = 80
	cpp.initial_velocity_max = 180
	cpp.gravity = Vector2(0, 200)
	cpp.scale_amount_min = 2
	cpp.scale_amount_max = 5
	cpp.color = Color(1, 0.85, 0.3)
	add(cp, cpp, "Particles")
	cp.body_entered.connect(Callable(cp, "_on_body_entered"), CONNECT_PERSIST)
	save_scene(cp, PF + "checkpoint.tscn")


func build_items() -> void:
	var items := {
		"coin": ["", 14.0, Color(1, 0.85, 0.3)],
		"gem": ["props/gem.png", 18.0, Color(0.5, 0.85, 1)],
		"heart": ["props/heart.png", 18.0, Color(1, 0.4, 0.5)],
		"life": ["props/life.png", 18.0, Color(1, 0.9, 0.3)],
		"speed": ["props/potion_speed.png", 18.0, Color(0.4, 0.7, 1)],
		"jump": ["props/potion_jump.png", 18.0, Color(0.5, 1, 0.4)],
	}
	for kind in items:
		var a := Area2D.new()
		a.name = "Item_" + kind
		a.collision_layer = L_ITEM
		a.collision_mask = L_PLAYER
		a.set_script(load(PF + "pickup.gd"))
		a.kind = kind
		if kind == "coin":
			add(a, anim_sprite("coin_frames", "spin"), "Sprite")
		else:
			add(a, sprite(items[kind][0]), "Sprite")
		add(a, circle_shape(items[kind][1]), "CollisionShape2D")
		var p := CPUParticles2D.new()
		p.amount = 6 if kind == "coin" else 10
		p.lifetime = 1.2
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 16
		p.gravity = Vector2(0, -20)
		p.scale_amount_min = 1.5
		p.scale_amount_max = 3
		p.color = items[kind][2]
		add(a, p, "Sparkle")
		a.body_entered.connect(Callable(a, "_on_body_entered"), CONNECT_PERSIST)
		save_scene(a, PF + "item_" + kind + ".tscn")


# ---------------------------------------------------------------------------
# Levels
# ---------------------------------------------------------------------------
const FLOOR_OBJECTS := {
	"C": "checkpoint.tscn", "^": "trap_spikes.tscn", "S": "trap_spear.tscn", "F": "trap_fire.tscn",
	"J": "jump_pad.tscn", "1": "portal.tscn", "2": "portal.tscn",
}
const ENEMIES := {
	"z": "zombie.tscn", "b": "zombie_boar.tscn", "f": "ghost_wasp.tscn", "K": "necro_knight.tscn",
	"E": "zombie_grave.tscn",
}
const ITEMS := {"c": "coin", "g": "gem", "h": "heart", "L": "life", "s": "speed", "j": "jump"}
const DECOR := {
	"t": ["decor/tree_green.png", -2], "T": ["decor/tree_dark.png", -2], "d": ["decor/tree_dead.png", -2],
	"r": ["decor/rock_big.png", -1], "R": ["decor/rock_moss.png", -1], "m": ["decor/mushroom_big.png", 2],
	"k": ["decor/tomb_cross.png", -1], "o": ["decor/tomb_round.png", -1], "n": ["decor/fence.png", -1],
	"u": ["decor/bush_big.png", -1],
}


func read_level(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var meta := {"labels": []}
	var rows: Array[String] = []
	var in_map := false
	while not f.eof_reached():
		var line := f.get_line()
		if in_map:
			rows.append(line)
		elif line == "map:":
			in_map = true
		elif line.begins_with("label="):
			var p := line.substr(6).split(";", true, 2)
			meta.labels.append([int(p[0]), int(p[1]), p[2].replace("\\n", "\n")])
		elif "=" in line:
			var kv := line.split("=", true, 1)
			meta[kv[0]] = kv[1]
	while rows.size() > 0 and rows[-1].strip_edges() == "":
		rows.pop_back()
	meta.rows = rows
	meta.w = 0
	for r in rows:
		meta.w = max(meta.w, r.length())
	return meta


func cell(rows: Array, x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0:
		return " "
	var r: String = rows[y]
	return r[x] if x < r.length() else " "


func is_solid(rows: Array, x: int, y: int) -> bool:
	if y >= rows.size():
		return true
	return cell(rows, x, y) in ["#", "B"]


func build_level(n: int) -> void:
	var lv := read_level("res://tools/levels/level_%02d.txt" % n)
	print("level ", n, " ", lv.w, "x", lv.rows.size())
	var rows: Array = lv.rows
	var src := 0 if lv.theme == "forest" else 1
	var stone := n >= 3  # stone terrain in the graveyard & castle
	var base: PackedScene = load("res://Scenes/Levels/base_level.tscn")
	var root: Node2D = base.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	root.name = "Level%02d" % n
	root.level_title = lv.title
	root.level_subtitle = lv.subtitle
	root.music = load(LK + "audio/" + lv.music + ".wav")

	var level: Node2D = root.get_node("Level")
	# --- background: sky (screen space) + 3 parallax layers
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -20
	add(root, sky_layer, "Sky")
	var sky := TextureRect.new()
	sky.texture = tex("bg/sky_%s.png" % lv.bg)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add(sky_layer, sky, "SkyTexture")
	var layers := [["Background1", "far", 0.15, 120], ["Background2", "mid", 0.35, 220], ["Background3", "near", 0.6, 300]]
	for L in layers:
		var px: Parallax2D = level.get_node_or_null(L[0])
		if px == null:
			px = Parallax2D.new()
			add(level, px, L[0])
			level.move_child(px, 2)
		var t := tex("bg/%s_%s.png" % [L[1], lv.bg])
		px.z_index = -10
		px.scroll_scale = Vector2(L[2], 1.0)
		px.repeat_size = Vector2(t.get_width(), 0)
		px.repeat_times = 4
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.position = Vector2(0, L[3])
		add(px, s, "Layer")

	# --- tile layers
	var tileset: TileSet = load(LK + "last_knight_tileset.tres")
	var ground := TileMapLayer.new()
	ground.tile_set = tileset
	add(level, ground, "Ground")
	var deco := TileMapLayer.new()
	deco.tile_set = tileset
	deco.collision_enabled = false
	deco.z_index = 2
	add(level, deco, "GroundDeco")
	var water := TileMapLayer.new()
	water.tile_set = tileset
	water.collision_enabled = false
	water.z_index = 3
	water.modulate = Color(1, 1, 1, 0.85) if n < 3 else Color(0.6, 1.0, 0.6, 0.85)  # poison swamp later
	add(level, water, "Water")
	var decor_root := Node2D.new()
	add(level, decor_root, "Decor")
	var traps := Node2D.new()
	add(level, traps, "Traps")
	var objects := Node2D.new()
	add(level, objects, "Objects")

	var top_row := 6 if stone else 1
	var tip_row := 5 if stone else 0
	for y in rows.size():
		for x in lv.w:
			var c := cell(rows, x, y)
			match c:
				"#":
					var left := not is_solid(rows, x - 1, y)
					var right := not is_solid(rows, x + 1, y)
					var top := not is_solid(rows, x, y - 1)
					var bottom := not is_solid(rows, x, y + 1)
					var col := 0 if left else (4 if right else rng.randi_range(1, 3))
					var row := top_row + rng.randi_range(1, 2)
					if top:
						row = top_row
					elif bottom:
						row = top_row + 3
					ground.set_cell(Vector2i(x, y), src, Vector2i(col, row))
					if top and y > 0:
						deco.set_cell(Vector2i(x, y - 1), src, Vector2i(col, tip_row))
				"B":
					ground.set_cell(Vector2i(x, y), src, Vector2i(rng.randi_range(10, 12), rng.randi_range(12, 13)))
				"=":
					var pl := 6
					if cell(rows, x - 1, y) != "=":
						pl = 5
					elif cell(rows, x + 1, y) != "=":
						pl = 7
					ground.set_cell(Vector2i(x, y), src, Vector2i(pl, 6))
				"~":
					water.set_cell(Vector2i(x, y), src, Vector2i(6 + x % 4, 19))
				"w":
					water.set_cell(Vector2i(x, y), src, Vector2i(6 + x % 4, 20))

	# --- objects
	var floor_pos := func(x: int, y: int) -> Vector2: return Vector2(x * T + T / 2.0, (y + 1) * T)
	var center_pos := func(x: int, y: int) -> Vector2: return Vector2(x * T + T / 2.0, y * T + T / 2.0)
	var portals := {}
	var count := {}
	for y in rows.size():
		for x in lv.w:
			var c := cell(rows, x, y)
			if c == " " or c in ["#", "B", "=", "~", "w"]:
				continue
			count[c] = count.get(c, 0) + 1
			var node: Node2D = null
			if c == "P":
				root.get_node("Player").position = floor_pos.call(x, y)
				root.get_node("Player").set("double_jump", true)
			elif c == "D":
				var door: Node2D = root.get_node("LevelFinishDoor")
				door.position = floor_pos.call(x, y)
				var next := "res://Scenes/Levels/level_%02d.tscn" % (n + 1)
				door.set("next_scene", load(next) if n < 4 else null)
			elif FLOOR_OBJECTS.has(c):
				node = (load(PF + FLOOR_OBJECTS[c]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				node.position = floor_pos.call(x, y)
				add(objects if c in ["C", "J", "1", "2"] else traps, node, "%s%d" % [node.name, count[c]])
				if c in ["1", "2"]:
					portals[c] = node
			elif c == "O":
				node = (load(PF + "trap_pendulum.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				node.position = Vector2(x * T + T / 2.0, y * T)
				add(traps, node, "Pendulum%d" % count[c])
			elif c in ["X", "Y"]:
				node = (load(PF + ("trap_saw.tscn" if c == "X" else "trap_saw_vertical.tscn")) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				node.position = center_pos.call(x, y)
				add(traps, node, "Saw%d" % count[c])
			elif c == "M":
				node = (load(PF + "moving_platform.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				node.position = Vector2(x * T + 48, y * T)
				var reach := 6
				for xx in range(x + 3, min(x + 10, lv.w)):
					var hit := false
					for yy in range(y, min(y + 4, rows.size())):
						if is_solid(rows, xx, yy):
							hit = true
					if hit:
						reach = max(2, xx - 3 - x)
						break
				node.set("offset", Vector2(reach * T, 0))
				node.set("duration", 0.6 * reach)
				add(objects, node, "MovingPlatform%d" % count[c])
			elif c == "V":
				node = (load(PF + "elevator.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				node.position = Vector2(x * T + 48, (y + 1) * T)
				var target := y
				for r in range(y, -1, -1):
					if is_solid(rows, x + 3, r) and not is_solid(rows, x + 3, r - 1):
						target = r
				node.set("offset", Vector2(0, (target - y - 1) * T))
				node.set("duration", 0.35 * (y + 1 - target))
				add(objects, node, "Elevator%d" % count[c])
			elif ENEMIES.has(c):
				node = (load(ACT + ENEMIES[c]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				node.position = center_pos.call(x, y) if c == "f" else floor_pos.call(x, y)
				add(root.get_node("Enemies"), node, "%s%d" % [node.name, count[c]])
			elif ITEMS.has(c):
				node = (load(PF + "item_" + ITEMS[c] + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				node.position = center_pos.call(x, y)
				add(root.get_node("Coins"), node, "%s%d" % [ITEMS[c].capitalize(), count[c]])
			elif DECOR.has(c):
				var d: Array = DECOR[c]
				var s := sprite(d[0], floor_pos.call(x, y) + Vector2(0, 4), true)
				s.z_index = d[1]
				if n >= 3 and c in ["t", "T", "u", "r", "R"]:
					s.modulate = Color(0.65, 0.6, 0.8)
				add(decor_root, s, "%s%d" % [d[0].get_file().get_basename(), count[c]])
			else:
				push_warning("unknown map char '%s' at %d,%d" % [c, x, y])
	if portals.has("1") and portals.has("2"):
		portals["1"].set("target", NodePath("../" + portals["2"].name))
		portals["2"].set("target", NodePath("../" + portals["1"].name))

	# --- hint labels
	var text_root: Node = root.get_node("Text")
	var theme: Theme = load("res://Scenes/Prefabs/theme.tres")
	var li := 0
	for L in lv.labels:
		li += 1
		var lab := Label.new()
		lab.theme = theme
		lab.text = L[2]
		lab.position = Vector2(L[0] * T, L[1] * T)
		lab.add_theme_font_size_override("font_size", 18)
		lab.add_theme_constant_override("outline_size", 6)
		lab.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
		add(text_root, lab, "Hint%d" % li)

	save_scene(root, "res://Scenes/Levels/level_%02d.tscn" % n)
