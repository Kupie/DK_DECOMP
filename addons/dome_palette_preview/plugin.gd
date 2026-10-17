@tool
extends EditorPlugin

var shader_layer: Control = null

func _process(delta):
	if not shader_layer:
		update_overlays()

func _exit_tree():
	if shader_layer:
		shader_layer.queue_free()

func _forward_canvas_draw_over_viewport(control):
	if not shader_layer:
		shader_layer = load("res://addons/dome_palette_preview/ShaderLayer.tscn").instantiate()
		control.add_child(shader_layer)
		shader_layer.set_viewport_texture(control.get_viewport().get_texture())

func handles(_object):
	return true
