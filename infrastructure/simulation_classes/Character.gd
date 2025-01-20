class_name Character
extends RigidBody

export var fall_limit = -100
export var gravity = -9.8
export var jump_speed = 3.0
export var run_speed = 10.0
export var walk_speed = 1.5
export var air_speed = 0.1
export var push_force = 1

var can_do_physics_activities = true
var body_collider = null
var stair_collider = null
var crouch_tween = null
var on_floor = false
var stair_rays = null
var stair_ray_bottom = null
var stair_ray_top = null
var using_stair = false
var stair_start_position = null
var stair_up_vec = null
var stair_up_distance = 0
var stair_fwd_vec = null
var stair_fwd_distance = 0
var stair_phase = 0
var stair_phase_frac = 0.0
var stair_speed = 2
var pre_stair_velocity = null
var velocity = Vector3.ZERO
var move_target = Vector3.ZERO
var move_direction = Vector3.ZERO
var crouch_time = 0.25
var crouching = false
var crouch_state = 1
var in_crouching_transition = false
var max_step_height = 0.2
var min_step_depth = 0.05
var climbing_ladder = false
var approach_ladder_speed = 3
var climb_ladder_speed = 5
var ladder = null
var ladder_attachment_point_position = null
var ladder_phase = 0
var should_jump = false
var should_run = false
var should_climb_up = false
var should_climb_down = false
var tick = 0

var temperature = 98.6

func _ready():
	body_collider = $body_collider
	stair_collider = $stair_collider
	crouch_tween = $crouch_tween
	stair_rays = $stair_rays
	stair_ray_bottom = $stair_rays/stair_ray_bottom
	stair_ray_top = $stair_rays/stair_ray_top




################ Event-driven UI ################


func toggle_crouch():
	if not in_crouching_transition:
		crouching = !crouching
		debug_info.log("crouching", crouching)
		
		crouch_tween.interpolate_method(
			self,
			"crouching_height_change",
			1 if crouching else 0,
			0 if crouching else 1,
			crouch_time,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN_OUT
		)
		in_crouching_transition = true
		crouch_tween.start()

func finished_crouching_transition():
	in_crouching_transition = false

func crouching_height_change(new_crouch_state):
	crouch_state = new_crouch_state
	





################ Physics-based UI ################



func _integrate_forces(state):
	for index in state.get_contact_count():
		if state.get_contact_local_shape(index) == body_collider.get_index() and\
			state.get_contact_local_normal(index).dot(Vector3.UP) > 0.9:
			on_floor = true
			return
	on_floor = false

func _physics_process(_delta):
	physics_activities()

func physics_activities():
	debug_info.log("using stairs", self.using_stair)
	debug_info.log("stair phase", self.stair_phase)
	debug_info.log("position", self.global_transform.origin)
	tick += 1
	if can_do_physics_activities:
		move()
		try_stairs()

func is_on_floor():
	return on_floor

func use_stair():

	if self.using_stair:
		if self.stair_phase == 0:
			var spacing = 0.005
			var top = stair_start_position + stair_up_vec + spacing*Vector3.UP
			var total_to_top = stair_up_vec + spacing*Vector3.UP
			var vec_to_top = top - self.global_transform.origin
			if vec_to_top.length() > spacing/2 and vec_to_top.dot(total_to_top) >= 0:
			
				var target_velocity = stair_speed * Vector3.UP
				self.apply_central_impulse(target_velocity - self.linear_velocity)

			else:
				self.linear_velocity = Vector3.ZERO
				self.stair_phase = 1

		elif self.stair_phase == 1:
			var fwd = stair_start_position + stair_up_vec + stair_fwd_vec
			var total_to_fwd = stair_fwd_vec
			var vec_to_fwd = fwd - self.global_transform.origin
			if vec_to_fwd.length() > 0.001 and vec_to_fwd.dot(total_to_fwd) >= 0:
			
				var target_velocity = stair_speed * stair_fwd_vec.normalized()
				self.apply_central_impulse(target_velocity - self.linear_velocity)

			else:
				self.linear_velocity = self.pre_stair_velocity
				self.stair_phase = 0
				self.using_stair = false
				self.gravity_scale = 1

func climb_ladder():

	if should_jump:
		var direction_away_from_ladder = self.global_transform.origin - self.ladder.global_transform.origin
		direction_away_from_ladder.y = 0
		self.drop_off_ladder()
		
		var jump_direction = (Vector3.UP + direction_away_from_ladder).normalized()
			
		self.apply_central_impulse(jump_speed * jump_direction)
		return

	var up_down = 0
	if should_climb_up:
		up_down = 1
	if should_climb_down:
		up_down = -1
	debug_info.log("ladder direction", up_down)
	
	debug_info.log("ladder phase", self.ladder_phase)
	if self.ladder_phase == 0:
		# moving to attachment point
		var direction = ladder_attachment_point_position - self.global_transform.origin

		var attach_distance = 0.01

		var distance_to_attachment_point = direction.length()
		debug_info.log("distance to attachment point", distance_to_attachment_point)
		
		if distance_to_attachment_point > attach_distance:
			var target_velocity = approach_ladder_speed*direction.normalized()
			self.apply_central_impulse(target_velocity - linear_velocity)
		else:
			ladder_phase = 1
		
	elif self.ladder_phase == 1:
		# moving on ladder
		var target_velocity = up_down * Vector3.UP
		self.apply_central_impulse(target_velocity - linear_velocity)

		var top_direction = ladder.top_attachment_point.global_transform.origin - self.global_transform.origin
		var bottom_direction = ladder.bottom_attachment_point.global_transform.origin - self.global_transform.origin
		
		if up_down > 0 and top_direction.y <= 0:
			debug_info.log("ladder", "getting off at top")
			self.climb_onto_surface()

		elif up_down < 0 and bottom_direction.y >= -0.1:
			debug_info.log("ladder", "getting off at bottom")
			self.drop_off_ladder()

func walk_run_jump():

	velocity = Vector3.ZERO
	move_direction = (move_target - self.global_transform.origin).normalized()
	debug_info.log("on floor", is_on_floor())
	# determine the horizontal velocity to move
	var speed
	if is_on_floor():
		# we're on the floor so we can move under our own power a lot

		if should_run:
			# we're running
			speed = run_speed
		else:
			# we're walking
			speed = walk_speed

		var vel = speed * move_direction
		velocity.x = vel.x
		velocity.z = vel.z
		
		# actual velocity we need to add is the target velocity minus current velocity
		velocity = velocity - Vector3(linear_velocity.x, 0, linear_velocity.z)

		# determine the vertical velocity
		if should_jump and self.is_on_floor():
			# we're jumping, so we just set the vertical speed
			velocity.y = jump_speed

		self.apply_central_impulse(velocity)

	elif Vector3(linear_velocity.x, 0, linear_velocity.z).length() < air_speed:
		# we're in the air and don't already have some momentum so we can move
		# tiny bit to get onto ledges

		speed = air_speed

		var vel = speed * move_direction
		velocity.x = vel.x
		velocity.z = vel.z

		self.apply_central_impulse(velocity)

	#prevents infinite falling
	if translation.y < fall_limit:
		scene_manager.reload_scene()

func move():

	if using_stair:
		use_stair()
		
	elif climbing_ladder:
		
		climb_ladder()
	
	else:
		walk_run_jump()

func try_stairs():
	if using_stair or not is_on_floor() or move_direction == Vector3.ZERO:
		return
		
	# The logic of trying to use stairs works like this:
	#
	# 1. Test if the path forward is obstructed. If not, then no possible step.
	# 2. Since we can move, we need to determine where we're going to land on
	#    the step. So we make three movements:
	#   1. A move up to the max step height
	#   2. A move forward to the min step depth
	#   3. A move back down to see where we land
	# 3. This total movement -- the travel -- defines the step. BUT! we might
	#    be on a ramp! So we need to see if the direct travel path is obstructed
	#    and if it is, there must be a step there, otherwise there's a ramp and
	#    we're not using stairs.
	
	# The result of motion tests
	var res
	
	# Here we move forward to test if we're obstructed
	var move_dir = 0.005 * move_direction.normalized()
	res = self.cast_stair_motion(self.global_transform.origin, move_dir, 0)
	if not res:
		# not colliding with anything, so must not be next to a step
		return
		
	# Well set the origin of future tests to be slightly away from the
	# obstruction, otherwise we might collide with it when we run the tests
	# for vertical motion
	var test_origin = self.global_transform.origin - 0.001*move_direction.normalized()
	
	# Here we test upward
	var up_dir = max_step_height * Vector3.UP
	var up_distance
	res = self.cast_stair_motion(test_origin, up_dir, 10);
	if not res:
		up_distance = 1
	else:
		up_distance = res[0]
	if up_distance == 0:
		return
	var up_dest = up_distance * up_dir
	
	# And now forward
	var fwd_dir = min_step_depth * move_direction.normalized()
	var fwd_distance
	res = self.cast_stair_motion(test_origin + up_dest, fwd_dir, 0)
	if not res:
		fwd_distance = 1
	else:
		fwd_distance = res[0]
	if fwd_distance < 1:
		return
	var fwd_dest = fwd_distance * fwd_dir
	
	# And now back down
	var down_dir = max_step_height * Vector3.DOWN
	var down_distance
	res = self.cast_stair_motion(test_origin + up_dest + fwd_dest, down_dir, 10)
	if not res:
		down_distance = 1
	else:
		down_distance = res[0]
	var down_dest = down_distance * down_dir
	# If we haven't travelled anywhere up a step or ramp, then we can just
	# quit early
	var travel = up_dest + fwd_dest + down_dest
	var travel_distance = travel.length()
	if travel_distance < 0.01 or travel.y <= 0:
		return
	
	# But otherwise we test if we're going up a ramp
	res = self.cast_stair_motion(self.global_transform.origin + 0.01 * Vector3.UP, travel, 5, true)
	if not res:
		return

	# We're not going up a ramp, so we must be at a step!
	using_stair = true
	stair_phase = 0
	stair_phase_frac = 0.0
	stair_start_position = self.global_transform.origin
	stair_up_vec = Vector3(0, travel.y, 0)
	stair_up_distance = travel.y
	stair_fwd_distance = min_step_depth
	stair_fwd_vec = min_step_depth * Vector3(travel.x, 0, travel.z).normalized()
	move_target = self.global_transform.origin
	self.pre_stair_velocity = self.linear_velocity
	self.linear_velocity = Vector3.ZERO
	self.gravity_scale = 0
		
func try_using_ladder(ladder_to_try):
	if climbing_ladder:
		self.drop_off_ladder()
		return
	
	var direction_to_bottom = ladder_to_try.bottom_reference.global_transform.origin - self.global_transform.origin
	var direction_to_top = ladder_to_try.top_reference.global_transform.origin - self.global_transform.origin
	debug_info.log("direction to bottom", direction_to_bottom)
	debug_info.log("direction to top", direction_to_top)
	
	debug_info.log("using ladder", true)
	debug_info.log("old gravity", self.gravity_scale)
	
	if direction_to_bottom.y >= 0 or direction_to_top.y <= 0:
		# we're either below the bottom, or above the top, so we move to the closest attachment point
		var distance_to_bottom = direction_to_bottom.length()
		var distance_to_top = direction_to_top.length()
		debug_info.log("distance to bottom", distance_to_bottom)
		debug_info.log("distance to top", distance_to_top)
		if distance_to_bottom <= distance_to_top:
			# attach to the bottom
			ladder_attachment_point_position = ladder_to_try.bottom_attachment_point.global_transform.origin

		else:
			# attach to the top of the ladder
			ladder_attachment_point_position = ladder_to_try.top_attachment_point.global_transform.origin
	else:
		# we're between the two attachment points so we grab onto the ladder there
		ladder_attachment_point_position = 0.5*(ladder_to_try.bottom_attachment_point.global_transform.origin + ladder_to_try.top_attachment_point.global_transform.origin)
		ladder_attachment_point_position.y = self.global_transform.origin.y

	
	climbing_ladder = true
	self.linear_velocity = Vector3.ZERO
	self.gravity_scale = 0
	self.ladder = ladder_to_try
	self.ladder_phase = 0
	debug_info.log("disabling_top_support", true)
	self.ladder.disable_top_support()

func drop_off_ladder():
	debug_info.log("ladder", "jumping off")
	debug_info.log("using ladder", false)
	climbing_ladder = false
	self.apply_central_impulse(-linear_velocity)
	self.gravity_scale = 1
	self.ladder = null

func climb_onto_surface():
	debug_info.log("ladder", "climbing up")
	debug_info.log("using ladder", false)
	self.ladder.enable_top_support()
	climbing_ladder = false
	self.apply_central_impulse(-linear_velocity)
	self.gravity_scale = 1
	# self.ladder.disable_top_support()
	self.ladder = null

func cast_stair_motion(origin : Vector3, dir : Vector3, recursive_steps : int, force_recursive_steps = false):
	var shape = stair_collider.shape
	# raise the shape by half its height so that its at the same position
	# as the collider, then add a millimeter so it doesnt collide with ground
	origin += Vector3(0,shape.height/2 + 0.001,0)
	
	# Create collision parameters
	var params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = origin + dir
	params.collide_with_bodies = true
	params.exclude = [self]
	params.margin = 0
	
	var space_state = get_world().direct_space_state
	var results = space_state.intersect_shape(params)
	if len(results) > 0 or force_recursive_steps:
		var lower = 0
		var upper = 1
		var mid = 0.5
		var forward
		var hit = false
		for _i in range(recursive_steps):
			mid = 0.5*(upper + lower)
			forward = mid*dir
			params.transform.origin = origin + forward
			var new_results = space_state.intersect_shape(params)
			if len(new_results) > 0:
				results = new_results
				upper = mid
				hit = true
			else:
				lower = mid
		
		if force_recursive_steps and not hit:
			return null
		
		return [mid, results]
	return null
