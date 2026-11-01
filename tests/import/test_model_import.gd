extends SceneTree
## Run with: godot --headless --path . --script tests/import/test_model_import.gd

const ImportFix = preload("res://addons/model_import_animation_fix/model_import.gd")
var failures: int = 0
var assertions: int = 0
var completed: int = 0


func _initialize() -> void:
  _test_nested_paths()
  for model in ["zombie1", "zombie2"]:
    _test_glb(model)
    _test_imported_scene(model)
  _check(completed == 5, "All import checks must finish without script errors")
  print("Model import regression: %d assertions, %d failures" % [assertions, failures])
  quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
  assertions += 1
  if not condition:
    failures += 1
    if failures <= 10:
      push_error(message)


func _test_nested_paths() -> void:
  var scene := Node3D.new()
  scene.name = "Model001"
  var rig := Node3D.new()
  rig.name = "Root001"
  scene.add_child(rig)
  var skeleton := Skeleton3D.new()
  skeleton.name = "Skeleton3D"
  skeleton.add_bone("LeftHandIndex1")
  rig.add_child(skeleton)
  var mesh := MeshInstance3D.new()
  mesh.name = "character002"
  skeleton.add_child(mesh)
  var player := AnimationPlayer.new()
  player.name = "AnimationPlayer"
  scene.add_child(player)
  player.root_node = NodePath("../Root001")
  var animation := Animation.new()
  animation.add_track(Animation.TYPE_POSITION_3D)
  animation.track_set_path(0, NodePath("Skeleton3D:LeftHandIndex1"))
  animation.position_track_insert_key(0, 0.0, Vector3(1, 2, 3))
  animation.add_track(Animation.TYPE_VALUE)
  animation.track_set_path(1, NodePath("Skeleton3D/character002:surface_material_override/0:albedo_color"))
  animation.track_insert_key(1, 0.0, Color.RED)
  var library := AnimationLibrary.new()
  library.add_animation("test", animation)
  player.add_animation_library("", library)

  var counts: Dictionary = ImportFix.normalize_scene(scene)
  _check(counts.nodes == 5 and counts.tracks == 2, "Each node and track should be counted once")
  _check(player.root_node == NodePath("../Root"), "Animation root must follow the renamed rig")
  _check(animation.track_get_path(0) == NodePath("Skeleton3D:LeftHandIndex1"), "Bone names, including digits, must survive")
  _check(animation.track_get_path(1) == NodePath("Skeleton3D/character:surface_material_override/0:albedo_color"), "Descendant names and complete property suffixes must be preserved")
  _check(animation.track_get_key_value(0, 0) == Vector3(1, 2, 3), "Transform keys must not change")
  var repeated: Dictionary = ImportFix.normalize_scene(scene)
  _check(repeated.renamed == 0 and repeated.updated_tracks == 0, "Normalization must be idempotent")
  scene.free()
  completed += 1


func _test_glb(model: String) -> void:
  var document := GLTFDocument.new()
  var state := GLTFState.new()
  var error := document.append_from_file("res://Assets/Models/%s.glb" % model, state)
  _check(error == OK, "Could not read %s" % model)
  if error != OK:
    return
  var scene := document.generate_scene(state)
  var nodes: Array[Node] = []
  _collect_nodes(scene, nodes)
  var transforms: Dictionary = {}
  var player: AnimationPlayer
  var skeleton: Skeleton3D
  for node in nodes:
    if node is Node3D:
      transforms[node] = node.transform
    if node is AnimationPlayer:
      player = node
    if node is Skeleton3D:
      skeleton = node
  _check(player != null and skeleton != null, "%s must contain a player and skeleton" % model)
  if player == null or skeleton == null:
    scene.free()
    return
  var originals: Dictionary = {}
  var key_times: Dictionary = {}
  for animation_name in player.get_animation_list():
    var original_animation := player.get_animation(animation_name)
    originals[animation_name] = original_animation.duplicate(true)
    # Animation.duplicate() round-trips times through packed float32 data.
    # Capture the actual times separately so this comparison can remain exact.
    key_times[animation_name] = []
    for track in original_animation.get_track_count():
      var times: Array[float] = []
      for key in original_animation.track_get_key_count(track):
        times.append(original_animation.track_get_key_time(track, key))
      key_times[animation_name].append(times)
  var bone_names: PackedStringArray = []
  var bone_rests: Array[Transform3D] = []
  for index in skeleton.get_bone_count():
    bone_names.append(skeleton.get_bone_name(index))
    bone_rests.append(skeleton.get_bone_rest(index))

  ImportFix.normalize_scene(scene)
  _check(scene.has_node("Root/Skeleton3D/character"), "%s canonical model path is missing" % model)
  _check(scene.has_node("AnimationPlayer"), "%s canonical player path is missing" % model)
  for node in transforms:
    _check(node.transform == transforms[node], "%s node transform changed" % model)
  for index in skeleton.get_bone_count():
    _check(skeleton.get_bone_name(index) == bone_names[index], "%s bone name changed" % model)
    _check(skeleton.get_bone_rest(index) == bone_rests[index], "%s bone rest changed" % model)
  for animation_name in player.get_animation_list():
    var original: Animation = originals[animation_name]
    var animation := player.get_animation(animation_name)
    _check(animation.get_track_count() == original.get_track_count(), "%s track count changed" % animation_name)
    for track in animation.get_track_count():
      var path := animation.track_get_path(track)
      _check(path.get_concatenated_subnames() == original.track_get_path(track).get_concatenated_subnames(), "%s bone/property suffix changed" % animation_name)
      _check(scene.get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton, "%s track must still target its skeleton" % animation_name)
      _check(animation.track_get_type(track) == original.track_get_type(track), "%s track type changed" % animation_name)
      _check(animation.track_get_key_count(track) == original.track_get_key_count(track), "%s key count changed" % animation_name)
      for key in animation.track_get_key_count(track):
        _check(animation.track_get_key_time(track, key) == key_times[animation_name][track][key], "%s key time changed" % animation_name)
        _check(animation.track_get_key_value(track, key) == original.track_get_key_value(track, key), "%s key value changed" % animation_name)
  scene.free()
  completed += 1


func _collect_nodes(node: Node, nodes: Array[Node]) -> void:
  nodes.append(node)
  for child in node.get_children():
    _collect_nodes(child, nodes)


func _test_imported_scene(model: String) -> void:
  var packed: PackedScene = load("res://Assets/Models/%s.glb" % model)
  var scene := packed.instantiate()
  var player: AnimationPlayer = scene.get_node("AnimationPlayer")
  var skeleton: Skeleton3D = scene.get_node("Root/Skeleton3D")
  var animation_root := player.get_node(player.root_node)
  _check(scene.has_node("Root/Skeleton3D/character"), "%s imported mesh path is missing" % model)
  _check(player.get_animation_list().size() == 7, "%s must retain all six clips and RESET" % model)
  for animation_name in player.get_animation_list():
    var animation := player.get_animation(animation_name)
    for track in animation.get_track_count():
      var path := animation.track_get_path(track)
      _check(animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton, "%s imported target must resolve to the skeleton" % animation_name)
      _check(path.get_subname_count() == 1, "%s imported track must target a bone" % animation_name)
      if path.get_subname_count() == 1:
        _check(skeleton.find_bone(path.get_subname(0)) >= 0, "%s imported bone must exist" % animation_name)
  scene.free()
  completed += 1
