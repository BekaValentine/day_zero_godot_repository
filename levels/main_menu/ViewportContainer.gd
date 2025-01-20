extends ViewportContainer


func _ready():
	self.material.set_shader_param("ViewportTexture", $Viewport.get_texture())
