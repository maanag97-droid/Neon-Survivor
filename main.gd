extends Node2D

var W := 720.0
var H := 1280.0

var player := Vector2(360, 760)
var hp := 3
var kills := 0
var score := 0
var best := 0
var alive := true
var dead_t := 0.0
var enemies: Array = []
var bullets: Array = []
var spawn_t := 0.5
var fire_t := 0.0
var inv_t := 0.0
var t_alive := 0.0
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var move_dir := Vector2.ZERO


func _ready() -> void:
	randomize()
	best = _load_best()
	_update_size()
	player = Vector2(W / 2.0, H * 0.6)


func _update_size() -> void:
	var s := get_viewport_rect().size
	W = s.x
	H = s.y


func _load_best() -> int:
	if FileAccess.file_exists("user://best.txt"):
		var f := FileAccess.open("user://best.txt", FileAccess.READ)
		if f:
			return int(f.get_as_text())
	return 0


func _save_best() -> void:
	var f := FileAccess.open("user://best.txt", FileAccess.WRITE)
	if f:
		f.store_string(str(best))


func _reset() -> void:
	player = Vector2(W / 2.0, H * 0.6)
	hp = 3
	kills = 0
	score = 0
	alive = true
	enemies.clear()
	bullets.clear()
	spawn_t = 0.5
	fire_t = 0.0
	inv_t = 0.0
	t_alive = 0.0
	move_dir = Vector2.ZERO
	stick_id = -1


func _die() -> void:
	alive = false
	dead_t = 0.0
	stick_id = -1
	move_dir = Vector2.ZERO
	if score > best:
		best = score
		_save_best()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not alive:
				if dead_t > 0.6:
					_reset()
				return
			if stick_id == -1:
				stick_id = event.index
				stick_origin = event.position
				stick_pos = event.position
		elif event.index == stick_id:
			stick_id = -1
			move_dir = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == stick_id:
		stick_pos = event.position
		move_dir = ((stick_pos - stick_origin) / 90.0).limit_length(1.0)


func _process(delta: float) -> void:
	_update_size()
	if alive:
		_update(delta)
	else:
		dead_t += delta
	queue_redraw()


func _spawn_enemy() -> void:
	var p := Vector2.ZERO
	match randi() % 4:
		0:
			p = Vector2(randf() * W, -30.0)
		1:
			p = Vector2(randf() * W, H + 30.0)
		2:
			p = Vector2(-30.0, randf() * H)
		_:
			p = Vector2(W + 30.0, randf() * H)
	var big := t_alive > 40.0 and randf() < 0.25
	enemies.append({"p": p, "hp": 3 if big else 1, "r": 30.0 if big else 20.0})


func _update(delta: float) -> void:
	t_alive += delta
	score = kills * 10 + int(t_alive)
	inv_t -= delta

	player += move_dir * 340.0 * delta
	player.x = clampf(player.x, 28.0, W - 28.0)
	player.y = clampf(player.y, 28.0, H - 28.0)

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.25, 1.0 - t_alive * 0.012)
		_spawn_enemy()

	var spd := minf(80.0 + t_alive * 1.5, 210.0)
	for en in enemies:
		var d: Vector2 = player - en["p"]
		en["p"] += d.normalized() * spd * delta

	fire_t -= delta
	if fire_t <= 0.0 and not enemies.is_empty():
		var best_d := INF
		var target := Vector2.ZERO
		for en in enemies:
			var dd: float = player.distance_to(en["p"])
			if dd < best_d:
				best_d = dd
				target = en["p"]
		fire_t = 0.22
		bullets.append({"p": player, "v": (target - player).normalized() * 720.0})

	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["p"] += b["v"] * delta
		var bp: Vector2 = b["p"]
		if bp.x < -20.0 or bp.x > W + 20.0 or bp.y < -20.0 or bp.y > H + 20.0:
			bullets.remove_at(i)
			continue
		for j in range(enemies.size() - 1, -1, -1):
			var tgt: Dictionary = enemies[j]
			var tr: float = tgt["r"]
			if bp.distance_to(tgt["p"]) < tr + 6.0:
				tgt["hp"] -= 1
				bullets.remove_at(i)
				if tgt["hp"] <= 0:
					enemies.remove_at(j)
					kills += 1
				break

	if inv_t <= 0.0:
		for j in range(enemies.size() - 1, -1, -1):
			var hit: Dictionary = enemies[j]
			var hr: float = hit["r"]
			if player.distance_to(hit["p"]) < hr + 22.0:
				enemies.remove_at(j)
				hp -= 1
				inv_t = 1.0
				Input.vibrate_handheld(120)
				if hp <= 0:
					_die()
				break


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.04, 0.09))
	var gx := 0.0
	while gx <= W:
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(0.1, 0.1, 0.2), 1.0)
		gx += 80.0
	var gy := 0.0
	while gy <= H:
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(0.1, 0.1, 0.2), 1.0)
		gy += 80.0

	for en in enemies:
		draw_circle(en["p"], en["r"], Color(1.0, 0.25, 0.3))
	for b in bullets:
		draw_circle(b["p"], 6.0, Color(1.0, 0.9, 0.3))

	if alive and (inv_t <= 0.0 or int(inv_t * 10.0) % 2 == 0):
		draw_circle(player, 22.0, Color(0.2, 0.9, 1.0))

	if stick_id != -1:
		draw_arc(stick_origin, 90.0, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
		var knob := stick_origin + (stick_pos - stick_origin).limit_length(90.0)
		draw_circle(knob, 34.0, Color(1, 1, 1, 0.35))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24, 60), "Score %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	draw_string(font, Vector2(24, 108), "HP %d" % maxi(hp, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	draw_string(font, Vector2(24, 60), "Best %d" % best, HORIZONTAL_ALIGNMENT_RIGHT, W - 48.0, 40)

	if not alive:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, H * 0.4), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, W, 72)
		draw_string(font, Vector2(0, H * 0.4 + 70), "Score %d" % score, HORIZONTAL_ALIGNMENT_CENTER, W, 44)
		if dead_t > 0.6:
			draw_string(font, Vector2(0, H * 0.4 + 140), "Tap to restart", HORIZONTAL_ALIGNMENT_CENTER, W, 36)
	elif t_alive < 4.0:
		draw_string(font, Vector2(0, H * 0.85), "Touch and drag to move. Auto-fire.", HORIZONTAL_ALIGNMENT_CENTER, W, 32)
