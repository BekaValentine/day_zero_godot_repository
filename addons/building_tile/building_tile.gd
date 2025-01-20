tool
extends EditorPlugin

var dock
var button

var editor_interface = get_editor_interface()
var current_path = null

func _enter_tree():
	dock = preload("res://addons/building_tile/building_tile.tscn").instance()
	self.add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)

	button = Button.new()
	dock.add_child(button)
	button.text = "Import Building Tiles"
	button.connect("pressed", self, "import_building_tiles")

func _exit_tree():
	self.remove_control_from_docks(dock)
	dock.free()

func _process(_delta):
	var path = editor_interface.get_current_path()
	if self.current_path != path:
	    self.current_path = path

func import_building_tiles():
	if self.current_path == null:
		print("Building Tiles: Error: null resource")
		return
	
	print("Building Tiles: Importing " + self.current_path)

	var destination = self.current_path.rsplit("/", false, 1)[0]
	print("Building Tiles: Import destination is " + destination)

	print("Building Tiles: Working... Please wait...")
	var dir = Directory.new()
	dir.open(self.current_path)
	dir.list_dir_begin(true, true)
	var file_name
	var part_name
	var extension
	var full_path
	var tile
	var extracted
	var packed
	var packed_destination
	while true:
		file_name = dir.get_next()
		if file_name == "":
			break
		
		if file_name.length() > 5:
			part_name = file_name.substr(0, file_name.length() - 5)
			extension = file_name.substr(file_name.length() - 4)

			if extension == "gltf":
				full_path = self.current_path + file_name
				print("Building Tiles: Importing " + full_path)
				tile = ResourceLoader.load(full_path).instance()
				extracted = Spatial.new()
				extracted.name = part_name
				packed = PackedScene.new()
				extracted.add_child(tile)
				tile.owner = extracted
				packed.pack(extracted)
				packed_destination = destination + "/" + part_name + ".tscn"
				print("Building Tiles: Saving to " + packed_destination)
				ResourceSaver.save(packed_destination, packed)

	dir.list_dir_end()

	# var glb_instance = res.instance()

	# var part_names = [ "corner", "middle", "door", "left_edge", "right_edge", "back_corner", "back_middle", "back_door", "top" ]
	# var sub_meshes = {}
	# for child in glb_instance.get_children():
	# 	var name = child.name.to_lower().replace(" ", "_")
	# 	for part_name in part_names:
	# 		var index = name.find(part_name)
	# 		if index == 0:
	# 			if not (part_name in sub_meshes):
	# 				sub_meshes[part_name] = []
	# 			sub_meshes[part_name].append(child)
	
	# for part_name in sub_meshes:
		# var extracted = Spatial.new()
		# extracted.name = part_name
	# 	var parts = sub_meshes[part_name]
	# 	var packed = PackedScene.new()
	# 	for part in parts:
	# 		part.get_parent().remove_child(part)
	# 		extracted.add_child(part)
	# 		part.owner = extracted
	# 	packed.pack(extracted);

	# 	var packed_destination = destination + "/" + part_name + ".tscn"
	# 	print("Building Tiles: Saving to " + packed_destination)
	# 	ResourceSaver.save(packed_destination, packed)
	
	print("Building Tiles: Done!")
