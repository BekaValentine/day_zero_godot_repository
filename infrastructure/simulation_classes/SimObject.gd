extends Spatial

class_name SimObject

# hold_size is how big the object is for holding/stashing purposes
# null means not holdable or stashable
# integer sizes mean how much bag space it takes up (0 means no space)
var hold_size = null
var holdable setget, get_holdable
func get_holdable():
	return hold_size != null

# useable_or_affected_by_tools is whether or not the object can be used or affected by tools
var useable_or_affected_by_tools = false

var meshes = []
var focal_object_resource = null
var focal_object = null

var destroyed = false

func _ready():
	add_visual_instances(self)

func add_visual_instances(node):
	# debug_info.log("trying add mesh for " + str(node), true)
	if node is VisualInstance:
		meshes.push_back(node)
	for c in node.get_children():
		add_visual_instances(c)

func move_meshes_to_layers(layers):
	for m in meshes:
		m.layers = layers

func can_highlight():
	return self.get_holdable() or self.can_use_or_affect() or focal_object_resource != null

func can_use_or_affect():
	return self.useable_or_affected_by_tools and not self.destroyed

#### Internal Functions MUST NOT OVERRIDE ####

func _start_highlight():
	self.start_highlight()
	
func _end_highlight():
	self.end_highlight()

func _hold():
	if not self.holdable: return

	self.move_meshes_to_layers(2)
	
	self.hold()

func _release():
	if not self.holdable: return
	
	self.move_meshes_to_layers(1)
	
	self.release()
	
func _stash():
	if not self.holdable: return
	
	self.stash()

func _unstash():
	if not self.holdable: return
	
	self.unstash()

func _use_on(agent, patient):
	return self.use_on(agent, patient)

func _affected_by(agent, tool_object = null):
	debug_info.log("being used", [self, self.can_use_or_affect(), randf()])
	if not self.can_use_or_affect(): return
	
	debug_info.log("being used 2", [self, self.can_use_or_affect(), randf()])
	self.affected_by(agent, tool_object)

func _focus():
	self.focus()
	focal_object = focal_object_resource.instance()
	return focal_object

func _unfocus():
	focal_object = null

func _focus_left():
	self.focus_left()

func _focus_right():
	self.focus_right()

func _focus_up():
	self.focus_up()

func _focus_down():
	self.focus_down()


#### Exposed Functions MAY OVERRIDE ####

func start_highlight():
	pass

func end_highlight():
	pass

func hold():
	pass

func release():
	pass

func stash():
	pass

func unstash():
	pass

func use_on(agent, patient):
	# default behavior is to simply pass control to the patient
	patient._affected_by(agent, self)
	return null

func affected_by(_agent, _tool_object):
	pass

func focus():
	pass

func unfocus():
	pass

func focus_left():
	pass

func focus_right():
	pass

func focus_up():
	pass

func focus_down():
	pass

func destroy():
	pass
