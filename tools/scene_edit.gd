extends SceneTree
## Sets node properties in a .tscn the way the editor does (open, change, pack, save), so
## nobody hand-writes scene syntax, node IDs or uid:// values. Used by Claude for small edits.
## Properties and node removal only: add or move nodes in the Godot editor.
##
## godot --headless --path . -s tools/scene_edit.gd -- <scene.tscn> <node> <property> <value> [...]
## godot --headless --path . -s tools/scene_edit.gd -- <scene.tscn>     (re-save only: adds uid and node ids)
## godot --headless --path . -s tools/scene_edit.gd -- --remove <scene.tscn> <node> [<node> ...]
##   (removes the nodes with their children; resources only they used drop out of the file)
##   <node>     path from the scene root, "." for the root itself
##   <property> any property, including "theme_override_constants/separation"
##   <value>    GDScript literal parsed by str_to_var: 624, true, "Play", &"AccentButton",
##              Vector2(624, 0), Color(1, 0.8, 0.3, 1); or a res:// path, which is loaded
##              (for `script` or any resource property)
## Repeat <node> <property> <value> for more edits in the same scene. After saving, the scene
## is reloaded and every edit re-checked: nodes inside an instanced child scene only keep
## changes when that instance has Editable Children on, and the tool reports it if not.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "--remove":
		quit(_remove(args[1], args.slice(2)))
		return
	if args.size() == 1:
		# Just the scene: re-save it in Godot's own format (adds the uid and node ids to a
		# scene that was written as text).
		quit(_edit(args[0], PackedStringArray()))
		return
	if args.size() < 4 or (args.size() - 1) % 3 != 0:
		printerr("usage: -s tools/scene_edit.gd -- <scene.tscn> [<node> <property> <value> ...]")
		quit(2)
		return
	quit(_edit(args[0], args.slice(1)))


func _edit(path: String, edits: PackedStringArray) -> int:
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("scene_edit: cannot load ", path)
		return 1
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var failed := false
	for i in range(0, edits.size(), 3):
		var node := root.get_node_or_null(NodePath(edits[i]))
		var property := edits[i + 1]
		var value: Variant = _parse(edits[i + 2])
		if node == null:
			printerr("scene_edit: no node '%s' in %s" % [edits[i], path])
			failed = true
		elif value == null and edits[i + 2] != "null":
			printerr("scene_edit: cannot parse value '%s'" % edits[i + 2])
			failed = true
		else:
			node.set(property, value)
			if node.get(property) != value:
				printerr("scene_edit: %s.%s did not take the value %s" % [edits[i], property, edits[i + 2]])
				failed = true
			else:
				print("scene_edit: %s %s = %s" % [edits[i], property, edits[i + 2]])
	if failed:
		root.free()
		return 1
	if _save(path, packed, root) != OK:
		return 1
	return _verify(path, edits)


## Removes nodes (with their children) and saves; then checks they are really gone.
func _remove(path: String, nodes: PackedStringArray) -> int:
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("scene_edit: cannot load ", path)
		return 1
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	for node_path in nodes:
		var node := root.get_node_or_null(NodePath(node_path))
		if node == null or node == root:
			printerr("scene_edit: no removable node '%s' in %s" % [node_path, path])
			root.free()
			return 1
		node.get_parent().remove_child(node)
		node.free()
		print("scene_edit: removed ", node_path)
	if _save(path, packed, root) != OK:
		return 1
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var check := saved.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var left := 0
	for node_path in nodes:
		if check.get_node_or_null(NodePath(node_path)) != null:
			printerr("scene_edit: %s is still in the file" % node_path)
			left += 1
	check.free()
	return 1 if left > 0 else 0


## Packs the edited tree into the scene and saves it, keeping the scene's uid.
func _save(path: String, packed: PackedScene, root: Node) -> Error:
	var uid := ResourceLoader.get_resource_uid(path)
	var err := packed.pack(root)
	root.free()
	if err == OK:
		err = ResourceSaver.save(packed)
	# Outside the editor the saver does not know the scene's uid, so write the old one back
	# (or give a scene that never had one its first uid).
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
		ResourceUID.add_id(uid, path)
	if err == OK:
		err = ResourceSaver.set_uid(path, uid)
	if err != OK:
		printerr("scene_edit: saving %s failed: %s" % [path, error_string(err)])
		return err
	print("scene_edit: saved ", path)
	return OK


## Reloads the saved file and checks that every edit is really in it.
func _verify(path: String, edits: PackedStringArray) -> int:
	var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var root := saved.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var lost := 0
	for i in range(0, edits.size(), 3):
		var node := root.get_node_or_null(NodePath(edits[i]))
		if node == null or node.get(edits[i + 1]) != _parse(edits[i + 2]):
			printerr("scene_edit: %s.%s was not kept in the file. Is the node inside an instanced scene without Editable Children?" % [edits[i], edits[i + 1]])
			lost += 1
	root.free()
	return 1 if lost > 0 else 0


func _parse(text: String) -> Variant:
	if text.begins_with("res://"):
		return load(text)
	return str_to_var(text)
