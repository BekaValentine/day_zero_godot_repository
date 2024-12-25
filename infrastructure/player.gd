extends Character

export var mouse_sensitivity = 0.002

var backpack = null
var reticle = null
var pivot = null
var camera = null
var hold_camera = null
var hold_position = null
var pickup_detect_ray = null
var highlighted_object = null
var held_object = null
var should_show_highlight = true
var self_initial_rotation = Vector3.ZERO
var held_object_initial_rotation = Vector3.ZERO
var inventory_open = false
var should_move_forward = false
var should_move_backward = false
var should_move_left = false
var should_move_right = false
var stand_height = null
var crouch_height = 0.75

enum { UIMODE_FPCONTROL, UIMODE_FOCUSING, UIMODE_TOOL_OVERLAY }
var ui_modes = [UIMODE_FPCONTROL];

var focus_stack = []
var focal_objects = null
var focus_camera = null
var focus_background_hider = null
var focal_object_depth_offset = 0.5
var focal_object_horizontal_offset = 0.2
var overlay_layer = null

var reticle_cursor = load("res://infrastructure/ui/reticle.png")


var WORLD_OBJECT_COLLISION_MASK = 2
var HELD_COLLISION_MASK = 0
var NORMAL_COLLISION_MASK = 2 | 4
var FOCUS_COLLISION_MASK = 8

var skills = {
	"lock": 0
}



func _ready():
	._ready()
	
	backpack = $backpack
	reticle = $reticle_center/reticle
	pivot = $pivot
	camera = $pivot/camera
	hold_camera = $hold_layer/hold_viewport_container/hold_viewport/hold_camera
	hold_position = $pivot/hold_position
	pickup_detect_ray = $pivot/pickup_detect_ray
	focal_objects = $focus_layer/focal_objects
	focus_camera = $focus_layer/focus_object_viewport_container/focus_object_viewport/focus_camera
	focus_background_hider = $focus_layer/focus_object_viewport_container/focus_object_viewport/focus_camera/background_hider
	overlay_layer = $overlay_layer

	stand_height = pivot.transform.origin.y
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)





################ Event-driven UI ################



func _unhandled_input(event):
	if ui_modes[-1] == UIMODE_FPCONTROL:
		if event is InputEventMouseMotion:
			self.rotate_y(-event.relative.x * mouse_sensitivity)
			pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			pivot.rotation.x = clamp(pivot.rotation.x, -1.2, 1.2)
			hold_camera.global_transform = camera.global_transform
		
		elif Input.is_action_just_pressed("crouch"):
			toggle_crouch()
		
		elif Input.is_action_just_pressed("primary_interaction"):
			if held_object:
				throw_object()
			
			elif highlighted_object:
				if highlighted_object is SimObject and highlighted_object.holdable:
					pickup_object()
					

		elif Input.is_action_just_pressed("secondary_interaction"):
			if held_object:
				drop_object()

		elif Input.is_action_just_pressed("take"):
			if held_object:
				if held_object:
					take_object()
		
		elif Input.is_action_just_pressed("use"):
			if highlighted_object and highlighted_object is SimObject and highlighted_object.can_use_or_affect():
				use_object()
		
		elif Input.is_action_just_pressed("focus"):
			if highlighted_object and highlighted_object is SimObject and highlighted_object.focal_object_resource:
				focus_object(highlighted_object)
		
		elif Input.is_action_just_pressed("backpack"):
			self.toggle_backpack()
	
	elif ui_modes[-1] == UIMODE_FOCUSING:
		if event is InputEventMouseMotion:
			focus_interact_objects()

		elif Input.is_action_just_pressed("use"):
			if highlighted_object and highlighted_object is SimObject and highlighted_object.can_use_or_affect():
				use_object()

		elif Input.is_action_just_pressed("unfocus"):
			unfocus_object()
		
		elif Input.is_action_just_pressed("focus"):
			if highlighted_object and highlighted_object is SimObject and highlighted_object.focal_object_resource:
				self.focus_object(highlighted_object)

		elif Input.is_action_just_pressed("focus_left"):
			focus_stack[-1]._focus_left()
		
		elif Input.is_action_just_pressed("focus_right"):
			focus_stack[-1]._focus_right()

		elif Input.is_action_just_pressed("focus_up"):
			focus_stack[-1]._focus_up()

		elif Input.is_action_just_pressed("focus_down"):
			focus_stack[-1]._focus_down()

	elif ui_modes[-1] == UIMODE_TOOL_OVERLAY:
		
		if Input.is_action_just_pressed("exit_overlay"):
			self.exit_overlay()

func crouching_height_change(h):
	.crouching_height_change(h)

	pivot.transform.origin.y = lerp(crouch_height, stand_height, crouch_state)
	
	if held_object:
		set_held_object_position()

func finished_crouching_transition():
	.finished_crouching_transition()
	var true_height = pivot.transform.origin.y + self.body_collider.shape.radius
	self.body_collider.shape.height = true_height - 2*self.body_collider.shape.radius
	self.body_collider.translation.y = true_height/2

func pickup_object():
	hold_object(highlighted_object)
	self.set_highlighted_object(null)

func hold_object(obj):	
	held_object = obj
	if not held_object.get_parent():
		self.get_parent().add_child(held_object)
	self_initial_rotation = self.get_rotation()
	if held_object.transform.basis.y.angle_to(Vector3.UP) > 0.01:
		held_object_initial_rotation = Vector3.ZERO
	else:
		held_object_initial_rotation = held_object.get_rotation()
	held_object.mode = RigidBody.MODE_KINEMATIC
	held_object.collision_mask = HELD_COLLISION_MASK
	held_object._hold()

func throw_object():
	held_object._release()
	var old_transform = held_object.global_transform
	held_object.mode = RigidBody.MODE_RIGID
	held_object.collision_mask = NORMAL_COLLISION_MASK
	held_object.global_transform = old_transform
	held_object.apply_impulse(Vector3(0,0,0), -10*camera.global_transform.basis.z)
	held_object = null

func drop_object():
	held_object._release()
	var old_transform = held_object.global_transform
	held_object.mode = RigidBody.MODE_RIGID
	held_object.collision_mask = NORMAL_COLLISION_MASK
	held_object.global_transform = old_transform
	held_object = null

func take_object():
	held_object._stash()
	backpack.store_item(held_object)
	held_object.get_parent().remove_child(held_object)
	held_object = null
	
func use_object():
	if held_object:
		var overlay = held_object._use_on(self, highlighted_object)
		if overlay != null:
			debug_info.log("overlay", true)
			overlay.set_active(true)
			self.ui_modes.push_back(UIMODE_TOOL_OVERLAY)
			self.overlay_layer.add_child(overlay)
	else:
		highlighted_object._affected_by(self)

func focus_object(focused_object):
	ui_modes.push_back(UIMODE_FOCUSING)
	self.set_highlighted_object(null)
	reticle.visible = false
	Input.set_custom_mouse_cursor(reticle_cursor)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	focus_background_hider.visible = true
	var focal_object = focused_object._focus()
	focus_stack.push_back(focal_object)

	focal_objects.add_child(focal_object)
	focal_object.global_transform.origin = Vector3(0, 0, focal_object_depth_offset*(len(focal_objects.get_children()) - 1))
	focus_camera.global_transform.origin.z += focal_object_depth_offset
	focal_object.rotate_y(0.1 * (len(focal_objects.get_children()) - 1))
	focal_object.global_transform.origin.x = focal_object_horizontal_offset*(len(focal_objects.get_children()) - 1)
	focus_camera.global_transform.origin.x += focal_object_horizontal_offset
	debug_info.log("focus_camera position", focus_camera.transform.origin)

func unfocus_object():
	self.set_highlighted_object(null)
	
	if len(focus_stack) > 0:
		focal_objects.remove_child(focus_stack[-1])
		focus_stack.pop_back()

	var focusing_on_object = len(focus_stack) > 0
	reticle.visible = !focusing_on_object
	if !focusing_on_object:
		ui_modes.pop_back()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	focus_background_hider.visible = focusing_on_object
	focus_camera.global_transform.origin.z -= focal_object_depth_offset
	focus_camera.global_transform.origin.x -= focal_object_horizontal_offset

func exit_overlay():
	self.ui_modes.pop_back()
	for n in self.overlay_layer.get_children():
		self.overlay_layer.remove_child(n)
		n.set_active(false)

func toggle_backpack():
	if not backpack.visible:
	# 	self.hide_backpack()
	# else:
		self.show_backpack()

func show_backpack():
	self.set_process_unhandled_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	backpack.show()

func hide_backpack():
	self.set_process_unhandled_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	backpack.hide()

func stash_object(obj):
	obj._stash()
	backpack.store_item(obj)

func unstash_object(obj):
	if held_object: return false
	
	self.hide_backpack()
	obj._unstash()
	self.hold_object(obj)

	return true

func focus_interact_objects():
	var mouse_position = self.get_viewport().get_mouse_position()
	var ray_length = 10
	var from = focus_camera.project_ray_origin(mouse_position)
	var to = from + focus_camera.project_ray_normal(mouse_position) * ray_length
	var space = self.get_world().direct_space_state
	var raycast_hit = space.intersect_ray(from, to, [], FOCUS_COLLISION_MASK)
	if "collider" in raycast_hit:
		if raycast_hit.collider is SimObject and !highlighted_object:
			self.set_highlighted_object(raycast_hit.collider)
	else:
		if highlighted_object:
			self.set_highlighted_object(null)





################ Physics-based UI ################

func physics_activities():
	if ui_modes[-1] == UIMODE_FPCONTROL:
		calculate_behavior_from_user_inputs()
		.physics_activities()
		interact_objects()
		rotate_held_object()


func calculate_behavior_from_user_inputs():
	should_move_forward = Input.is_action_pressed("move_forward")
	should_move_backward = Input.is_action_pressed("move_backward")
	should_move_left = Input.is_action_pressed("move_left")
	should_move_right = Input.is_action_pressed("move_right")

	should_jump = Input.is_action_just_pressed("jump")
	should_run = Input.is_action_pressed("run")
	should_climb_up = Input.is_action_pressed("move_forward")
	should_climb_down = Input.is_action_pressed("move_backward")

	# set the move target
	move_target = self.global_transform.origin #camera.global_transform.origin + -camera.global_transform.basis.z

	# determine the direction to move in
	var basis = global_transform.basis
	if should_move_forward:
		move_target -= basis.z
	if should_move_backward:
		move_target += basis.z
	if should_move_left:
		move_target -= basis.x
	if should_move_right:
		move_target += basis.x

	debug_info.log("move target", move_target)

func move():
	.move()

	hold_camera.global_transform = camera.global_transform

func set_highlighted_object(obj):
	debug_info.log("setting highlighted", str(obj))

	if obj != highlighted_object:
		if highlighted_object and highlighted_object is SimObject:
			highlighted_object._end_highlight()
		
		if obj and obj is SimObject:
			obj._start_highlight()
		
		highlighted_object = obj

func interact_objects():
	
	var raycast_hit = pickup_detect_ray.get_collider()

	debug_info.log("player.interact_objects", raycast_hit.name if raycast_hit else "no usable object")
	
	if raycast_hit and \
		raycast_hit is SimObject and \
		raycast_hit.can_highlight():
		
		self.set_highlighted_object(raycast_hit)
	else:
		self.set_highlighted_object(null)

func rotate_held_object():
	if held_object:
		set_held_object_position()
		var delta_rotation = self.get_rotation() - self_initial_rotation
		held_object.set_rotation(held_object_initial_rotation + delta_rotation)

func viewing_ui():
	return backpack.visible

func set_held_object_position():
	held_object.global_transform.origin = hold_position.global_transform.origin
