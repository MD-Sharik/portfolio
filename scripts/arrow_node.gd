extends Node2D
## One node per arrow. It only redraws when that arrow changes (slide, bump, hint, theme),
## so boards with thousands of arrows (128x128) stay cheap while panning and zooming.

var board
var id := 0


func _draw() -> void:
	board.draw_arrow(self, id)
