extends SceneTree

const PLAY_SELECT_SCENE := "res://Stages/UI/play_select/play_select.tscn"
const OUTPUT_DIR := "res://artifacts/visual/play_select"
const VIEWPORTS := {
  "1280x720": Vector2i(1280, 720),
}

var _capture_error_count := 0

func _initialize() -> void:
  call_deferred("_run")

func _run() -> void:
  _ensure_output_dir()
  for label in VIEWPORTS:
    await _capture_viewport(label, VIEWPORTS[label])
  quit(1 if _capture_error_count > 0 else 0)

func _ensure_output_dir() -> void:
  var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
  var error := DirAccess.make_dir_recursive_absolute(output_path)
  if error != OK:
    _record_capture_error("Failed to create output directory %s: %s" % [output_path, error])

func _capture_viewport(label: String, size: Vector2i) -> void:
  var viewport := SubViewport.new()
  viewport.size = size
  viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
  root.add_child(viewport)

  var screen: Control = load(PLAY_SELECT_SCENE).instantiate()
  viewport.add_child(screen)
  await _settle()

  _save_viewport_image(viewport, "play_select_%s.png" % label)
  viewport.queue_free()
  await process_frame

func _settle() -> void:
  await process_frame
  await process_frame

func _save_viewport_image(viewport: Viewport, file_name: String) -> void:
  print("Capturing %s at %sx%s" % [file_name, viewport.size.x, viewport.size.y])
  var texture := viewport.get_texture()
  if texture == null:
    _record_capture_error("Failed to capture %s: viewport texture is null" % file_name)
    return

  var image := texture.get_image()
  if image == null:
    _record_capture_error("Failed to capture %s: viewport image is null" % file_name)
    return

  var output_path := "%s/%s" % [OUTPUT_DIR, file_name]
  var error := image.save_png(output_path)
  if error != OK:
    _record_capture_error("Failed to save %s: %s" % [output_path, error])
  else:
    print("Saved %s" % output_path)

func _record_capture_error(message: String) -> void:
  _capture_error_count += 1
  push_error(message)
