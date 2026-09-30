extends Control

## Movimento sutil de varredura, renderizado apenas no monitor da televisão.
var _phase := 0.0

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	for y in range(0, 650, 8):
		draw_line(Vector2(0, y), Vector2(1000, y), Color(0.4, 0.75, 0.72, 0.025), 1.0)
	var sweep := fposmod(_phase * 95.0, 800.0) - 100.0
	draw_rect(Rect2(0, sweep, 1000, 46), Color(0.27, 0.67, 0.71, 0.035))
	draw_line(Vector2(40, 0), Vector2(40, 650), Color(0.54, 0.76, 0.72, 0.055), 1.0)
	draw_line(Vector2(960, 0), Vector2(960, 650), Color(0.54, 0.76, 0.72, 0.055), 1.0)
