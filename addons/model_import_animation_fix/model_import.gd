@tool
class_name FixAnimationPlayerTracksPlugin extends EditorScenePostImportPlugin

var _import_count: int = 0


func _get_import_options(_path: String) -> void:
  add_import_option_advanced(
    TYPE_BOOL,
    "fix_animation_player_tracks",
    false,
    PROPERTY_HINT_NONE,
    "Fixes the paths of AnimationPlayer tracks to remove trailing numbers from node names."
  )


func _pre_process(scene: Node) -> void:
  if not get_option_value("fix_animation_player_tracks"):
    return

  _import_count += 1
  var scene_name := scene.name
  var started := Time.get_ticks_usec()
  var counts := normalize_scene(scene)
  print("Model import #%d (%s): %d nodes, %d animations, %d tracks; %d nodes renamed, %d paths updated in %.2f ms" % [
    _import_count, scene_name, counts.nodes, counts.animations, counts.tracks,
    counts.renamed, counts.updated_tracks, (Time.get_ticks_usec() - started) / 1000.0
  ])


static func normalize_scene(scene: Node) -> Dictionary:
  var nodes: Array[Node] = []
  _collect_nodes(scene, nodes)
  var counts := {"nodes": nodes.size(), "animations": 0, "tracks": 0, "renamed": 0, "updated_tracks": 0}
  var names_by_parent: Dictionary = {}

  # Check the complete rename before changing anything. Otherwise Godot may
  # silently add a suffix to resolve two siblings with the same normalized name.
  for node in nodes:
    var normalized := String(node.name).rstrip("_0123456789")
    var parent := node.get_parent()
    if not names_by_parent.has(parent):
      names_by_parent[parent] = {}
    if normalized.is_empty() or names_by_parent[parent].has(normalized):
      push_error("Model import: cannot normalize node '%s' to '%s' without an empty or duplicate name." % [node.name, normalized])
      return counts
    names_by_parent[parent][normalized] = true

  var players: Array[Dictionary] = []
  var tracks: Array[Dictionary] = []
  # Resolve targets while all original names still exist. Holding node references
  # also handles renamed descendants and animation roots other than '..'.
  for node in nodes:
    if node is not AnimationPlayer:
      continue
    var player := node as AnimationPlayer
    var animation_root := player.get_node_or_null(player.root_node)
    if animation_root == null:
      push_error("Model import: missing animation root '%s'." % player.root_node)
      return counts
    players.append({"player": player, "root": animation_root})
    for animation_name in player.get_animation_list():
      counts.animations += 1
      var animation := player.get_animation(animation_name)
      for track_index in range(animation.get_track_count()):
        var path := animation.track_get_path(track_index)
        var target := animation_root if path.get_name_count() == 0 else animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
        if target == null:
          push_error("Model import: missing target '%s' in animation '%s'." % [path, animation_name])
          return counts
        tracks.append({"animation": animation, "index": track_index, "path": path, "root": animation_root, "target": target})
        counts.tracks += 1

  for node in nodes:
    var normalized := String(node.name).rstrip("_0123456789")
    if node.name != normalized:
      node.name = normalized
      counts.renamed += 1

  for entry in players:
    entry.player.root_node = entry.player.get_path_to(entry.root)
  for entry in tracks:
    var original: NodePath = entry.path
    var node_path: NodePath = entry.root.get_path_to(entry.target)
    var path := String(node_path)
    if original.get_subname_count() > 0:
      path += ":" + String(original.get_concatenated_subnames())
    if NodePath(path) != original:
      entry.animation.track_set_path(entry.index, NodePath(path))
      counts.updated_tracks += 1
  return counts


static func _collect_nodes(node: Node, nodes: Array[Node]) -> void:
  nodes.append(node)
  for child in node.get_children():
    _collect_nodes(child, nodes)

