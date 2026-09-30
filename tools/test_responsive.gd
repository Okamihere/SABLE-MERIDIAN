extends SceneTree

## Confere o HUD discreto e as notificações em tamanhos de tela diferentes.
const SIZES = [Vector2i(320, 568), Vector2i(360, 640), Vector2i(640, 360), Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(3840, 2160)]

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	for scene_path in ["res://scenes/levels/start_room.tscn", "res://scenes/levels/main.tscn"]:
		change_scene_to_file(scene_path)
		await frames(8)
		var hud := current_scene.get_node("HUD")
		assert(hud.get_node("Root").get_child_count() == 4, "HUD should contain vitals, target marker and contextual panels")
		assert(not current_scene.has_node("Instructions"), "The training overlay should be absent")
		for dims in SIZES:
			root.size = dims
			await frames(12)
			var area := Rect2(Vector2.ZERO, root.get_visible_rect().size / hud.scale)
			var vitals := hud.get_node("Root/Vitals") as Control
			if not area.grow(1).encloses(vitals.get_global_rect()):
				push_error("Vitals outside %s: %s" % [dims, vitals.get_global_rect()])
				quit(1)
				return
			var notice := hud.notice as Control
			if not area.grow(1).encloses(notice.get_global_rect()):
				push_error("Notice outside %s: %s" % [dims, notice.get_global_rect()])
				quit(1)
				return
			print("PASS %s %s" % [current_scene.name, dims])
	print("PASS: contextual HUD responsive layouts")
	quit()
