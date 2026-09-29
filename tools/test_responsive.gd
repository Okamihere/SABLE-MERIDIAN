extends SceneTree
## Testa tamanho real do viewport, redimensionamento e sobreposição do HUD.
## Inclui paisagem, retrato, ultrawide e alta resolução.
const SIZES = [Vector2i(320,568),Vector2i(360,640),Vector2i(640,360),Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(3440,1440),Vector2i(3840,2160)]
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	for scene in ["res://scenes/levels/start_room.tscn", "res://scenes/levels/main.tscn"]:
		change_scene_to_file(scene)
		await frames(8)
		for dims in SIZES:
			root.size = dims
			await frames(12)
			var hud = current_scene.get_node("HUD")
			root.get_node("Progression").notice_time = 100.0
			hud._on_style_changed(9999, 9999999, "S")
			await frames(4)
			var area = Rect2(Vector2.ZERO, root.get_visible_rect().size / hud.scale)
			var controls = [hud.get_node("Root/Vitals"),hud.get_node("Root/StylePanel"),hud.get_node("Root/Controls"),hud.notice_label]
			if current_scene.has_node("Instructions"):
				controls.append(current_scene.get_node("Instructions/Panel"))
			for control in controls:
				var bounds = control.get_global_rect()
				if not area.grow(1).encloses(bounds):
					push_error("Outside %s %s: %s area %s" % [dims,control.name,bounds,area])
					quit(1)
					return
			for i in controls.size():
				for j in range(i+1,controls.size()):
					if controls[i].get_global_rect().intersects(controls[j].get_global_rect()):
						push_error("Overlap %s: %s / %s" % [dims,controls[i].name,controls[j].name])
						quit(1)
						return
			if current_scene.has_node("Instructions"):
				current_scene.completed.clear()
				for lesson in current_scene.LESSONS:
					current_scene._update_help()
					await frames(4)
					var panel = current_scene.get_node("Instructions/Panel")
					if not area.grow(1).encloses(panel.get_global_rect()) or panel.get_global_rect().intersects(hud.get_node("Root/Controls").get_global_rect()) or panel.get_global_rect().intersects(hud.notice_label.get_global_rect()):
						push_error("Tutorial overlap %s: %s" % [dims, lesson[0]])
						quit(1)
						return
					current_scene.completed[lesson[0]] = true
			print("PASS %s %s" % [current_scene.name,dims])
	print("PASS: responsive layouts")
	quit()
