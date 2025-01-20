extends Spatial

var vertical_slice
var exit
var camera
var hit = null
var normal_color = null
var selected_button = null

# Called when the node enters the scene tree for the first time.
func _ready():
	vertical_slice = $menu/vertical_slice
	exit = $menu/exit
	camera = $Camera
	
func _process(_delta):
	test_menu_item_hit()

func _unhandled_input(_event):
	if Input.is_action_just_pressed("primary_interaction"):
		if selected_button == vertical_slice:
			scene_manager.goto_vertical_slice()
		elif selected_button == exit:
			get_tree().quit()

func test_menu_item_hit():
	var mouse_position = self.get_viewport().get_mouse_position()
	var ray_length = 2
	var from = camera.project_ray_origin(mouse_position)
	var to = from + camera.project_ray_normal(mouse_position) * ray_length
	var space = self.get_world().direct_space_state
	var raycast_hit = space.intersect_ray(from, to)

	if "collider" in raycast_hit:
		
		raycast_hit = raycast_hit.collider
	
		if raycast_hit != hit:
			
			if hit:
				print("mouse_out")
				hit.get_node("text").material = normal_color
		
			hit = raycast_hit
			var text = hit.get_node("text")
			normal_color = text.material.duplicate()
			text.material.emission_enabled = true
			text.material.emission = Color(0.1,0.15,0.2,1)
			selected_button = hit

	else:
		
		if hit:
				print("mouse_out")
				hit.get_node("text").material = normal_color
		hit = null
