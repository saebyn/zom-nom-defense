@tool
class_name FixAnimationPlayerTracksPlugin extends EditorScenePostImportPlugin


func _get_import_options(_path: String) -> void:
  add_import_option_advanced(
    TYPE_BOOL,
    "fix_animation_player_tracks",
    false,
    PROPERTY_HINT_NONE,
    "Fixes the paths of AnimationPlayer tracks to remove trailing numbers from node names."
  )


func _pre_process(scene):
  if get_option_value("fix_animation_player_tracks"):
    visit_pre(scene)


func visit_pre(node):
  if node != null:
    node.name = node.name.rstrip("_01234567890")
    if node is AnimationPlayer:
      fix_animation_player_tracks(node)

    for child in node.get_children():
      visit_pre(child)


func fix_animation_player_tracks(animation_player: AnimationPlayer) -> void:
  for animation_name in animation_player.get_animation_list():
    print("animation name: ", animation_name)
    var animation = animation_player.get_animation(animation_name)
    for track_index in range(animation.get_track_count()):
      var path = animation.track_get_path(track_index).get_concatenated_names()
      print("old path: ", path)
      var path_parts = path.split("/")
      # Remove the trailing numbers from the path
      var root_part = path_parts[0].rstrip("_01234567890")
      var new_path_parts = path_parts.slice(1)
      new_path_parts.insert(0, root_part)
      path = "/".join(new_path_parts)
      print("new path: ", path)
      animation.track_set_path(track_index, path)

