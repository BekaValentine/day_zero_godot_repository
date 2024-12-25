class_name Ladder
extends SimObject

var bottom_reference = null
var bottom_attachment_point = null
var top_reference = null
var top_attachment_point = null
var top_support = null

func _init():
	useable_or_affected_by_tools = true

func _ready():
	bottom_reference = $BottomReference
	bottom_attachment_point = $BottomAttachmentPoint
	top_reference = $TopReference
	top_attachment_point = $TopAttachmentPoint
	top_support = $TopSupport

func affected_by(agent, _tool_object):
	if agent.name == "player":
		agent.try_using_ladder(self)

func disable_top_support():
	top_support.disabled = true
	debug_info.log("ladder top support disabled", top_support.disabled)

func enable_top_support():
	top_support.disabled = false
	debug_info.log("ladder top support disabled", top_support.disabled)
