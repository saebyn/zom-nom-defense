extends Control
class_name MainUI

signal building_spawn_requested(building: Resource_BuildingType)
signal updated_bounding_box(new_bounds: AABB)

@onready var spawn_indicator: Control = $SpawnIndicator
@onready var hotbar: Control = $Hotbar
@onready var stats_display: Control = $StatsDisplay
@onready var fps_overlay: Control = $FpsOverlay
@onready var sound_effect_display: Control = $SoundEffectDisplay
@onready var cursor_tooltip: Control = $CursorTooltip
@onready var cursor_tooltip_label: Label = $CursorTooltip/TooltipLabel


func _process(_delta: float) -> void:
  if Input.is_action_just_pressed("toggle_in_game_menu"):
    GameManager.toggle_in_game_menu()
  elif Input.is_action_just_pressed("toggle_tech_tree"):
    _toggle_tech_tree()
  elif Input.is_action_just_pressed("toggle_stats"):
    _toggle_stats_display()
  elif Input.is_action_just_pressed("toggle_fps"):
    _toggle_fps_overlay()
  elif Input.is_action_just_pressed("toggle_sound_effects"):
    _toggle_sound_effect_display()


func _input(event: InputEvent) -> void:
  if event is InputEventMouseMotion:
    cursor_tooltip.position = event.position


func request_building_spawn(building: Resource_BuildingType) -> void:
  MyLogger.info("UI", "Requesting building spawn: %s" % building.name)
  building_spawn_requested.emit(building)

## Called when an enemy spawns to show the spawn indicator (legacy)
func _on_enemy_spawned(enemy: Node3D) -> void:
  if spawn_indicator and spawn_indicator.has_method("show_spawn_notification"):
    spawn_indicator.show_spawn_notification(enemy)
  # Also update wave progress if we have a current wave
  if spawn_indicator and spawn_indicator.has_method("_update_wave_display"):
    spawn_indicator._update_wave_display()

## Called when a wave starts to show wave information
func _on_wave_started(wave: System_Wave, wave_number: int) -> void:
  if spawn_indicator and spawn_indicator.has_method("show_wave_started"):
    spawn_indicator.show_wave_started(wave, wave_number)

## Called when a wave is completed
func _on_wave_completed(wave: System_Wave, wave_number: int) -> void:
  if spawn_indicator and spawn_indicator.has_method("show_wave_completed"):
    spawn_indicator.show_wave_completed(wave, wave_number)

## Called when a building is removed to show removal feedback
func show_building_removed(refund_amount: int) -> void:
  if spawn_indicator and spawn_indicator.has_method("show_building_removed"):
    spawn_indicator.show_building_removed(refund_amount)

## Called to show a problem message to the user (e.g. Twitch setup failed)
func show_problem_message(message: String) -> void:
  # This can be used for any non-critical issues that the user should be aware of, 
  # without disrupting gameplay with a modal dialog
  var dialog = AcceptDialog.new()
  dialog.dialog_text = message
  dialog.title = "Problem"
  # Connect the 'modal_closed' signal to free the dialog from memory when closed
  dialog.modal_closed.connect(func(): dialog.queue_free())
  get_tree().current_scene.add_child(dialog)
  dialog.popup_centered() # Make the dialog box visible and centered

## Toggle the tech tree UI visibility
func _toggle_tech_tree() -> void:
  MyLogger.info("UI", "Toggling Tech Tree UI")
  if GameManager.current_state == GameManager.GameState.IN_TECH_TREE:
    GameManager.set_game_state(GameManager.GameState.PLAYING)
  elif GameManager.is_playing():
    GameManager.pause_game()
    GameManager.set_game_state(GameManager.GameState.IN_TECH_TREE)

## Toggle the stats display visibility
func _toggle_stats_display() -> void:
  if stats_display:
    stats_display.toggle_visibility()
    MyLogger.info("UI", "Stats display toggled: %s" % ("visible" if stats_display.visible else "hidden"))

## Toggle the FPS overlay visibility
func _toggle_fps_overlay() -> void:
  if fps_overlay:
    fps_overlay.toggle_visibility()
    MyLogger.info("UI", "FPS overlay toggled: %s" % ("visible" if fps_overlay.visible else "hidden"))

## Toggle the sound effect display visibility
func _toggle_sound_effect_display() -> void:
  if sound_effect_display:
    sound_effect_display.toggle_display()
    MyLogger.info("UI", "Sound effect display toggled: %s" % ("visible" if sound_effect_display.visible else "hidden"))


## Methods to respond to building placement events,
## which can be connected to the BuildingPlacement signals

func building_placement_status(status: Utility_BuildingPlacement.BuildingPlacementStatus) -> void:
  if status == Utility_BuildingPlacement.BuildingPlacementStatus.NONE:
    cursor_tooltip.visible = false
  else:
    cursor_tooltip.visible = true

  match status:
    Utility_BuildingPlacement.BuildingPlacementStatus.NO_PLACEABLE_BUILDING:
      cursor_tooltip_label.text = "No placeable building selected."
    Utility_BuildingPlacement.BuildingPlacementStatus.OUTSIDE_BORDER:
      cursor_tooltip_label.text = "Cannot place building outside the border."
    Utility_BuildingPlacement.BuildingPlacementStatus.BUILDING_COLLISION:
      cursor_tooltip_label.text = "Cannot place building here: Collides with another building."
    Utility_BuildingPlacement.BuildingPlacementStatus.NO_TERRAIN_SUPPORT:
      cursor_tooltip_label.text = "Cannot place building here: Invalid terrain support."
    Utility_BuildingPlacement.BuildingPlacementStatus.INSUFFICIENT_CLEARANCE:
      cursor_tooltip_label.text = "Cannot place building here: Insufficient clearance."
    Utility_BuildingPlacement.BuildingPlacementStatus.INSUFFICIENT_FUNDS:
      cursor_tooltip_label.text = "Cannot place building here: Insufficient funds."
