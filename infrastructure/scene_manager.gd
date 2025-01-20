extends Node

var current_scene = "res://levels/main_menu/main_menu.tscn"
# "res://infrastructure/menus/main_menu.tscn"

func _ready():
	randomize()

func goto_scene(var s):
	current_scene = s
	get_tree().change_scene(s)

func reload_scene():
	goto_scene(current_scene)

func goto_main_menu():
	goto_scene("res://levels/main_menu/main_menu.tscn")

func goto_prototypes_menu():
	goto_scene("res://infrastructure/menus/prototypes_menu.tscn")

func goto_interactions_prototype():
	goto_scene("res://levels/prototypes/interactions.tscn")

func goto_locks_and_doors_prototype():
	goto_scene("res://levels/prototypes/locks_and_doors.tscn")

func goto_ladders_prototype():
	goto_scene("res://levels/prototypes/ladders.tscn")

func goto_inspection_prototype():
	goto_scene("res://levels/prototypes/inspection.tscn")

func goto_transmitters_prototype():
	goto_scene("res://levels/prototypes/transmitters.tscn")

func goto_vertical_slice():
	goto_scene("res://levels/vertical_slice/vertical_slice.tscn")
