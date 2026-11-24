@tool
extends DialogicPortrait

@onready var camera := $SubViewportContainer/SubViewport/Camera3D

func _update_portrait(character: DialogicCharacter, _portrait_name: String) -> void:
  if Engine.is_editor_hint():
    return
  if not is_node_ready():
    await ready

  MyLogger.info("Dialogic.CharacterPortrait", "Portrait updated")
  var group_name := "dialogic_portrait_" + character.get_identifier()
  var marker := get_tree().get_first_node_in_group(group_name) as Marker3D
  if marker != null:
    camera.global_transform = marker.global_transform


func _get_covered_rect() -> Rect2:
  return $SubViewportContainer.get_rect()
