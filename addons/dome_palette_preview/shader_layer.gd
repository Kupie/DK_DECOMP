@tool
extends PanelContainer

func _on_CheckButton_pressed():
	$Shader.visible = $CheckButton.button_pressed

func set_viewport_texture(viewport_texture: ViewportTexture):
	$Shader.material.set_shader_parameter("viewport", viewport_texture)
