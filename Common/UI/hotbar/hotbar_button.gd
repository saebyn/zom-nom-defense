class_name HotbarButton
extends Button

@onready var slot_label := $SlotLabel
@onready var cost_label := $CostLabel

## Custom tooltip to work around Godot's built-in tooltip timer not ticking when paused
var _tooltip_panel: PanelContainer
var _tooltip_label: Label
var _custom_tooltip_text: String = ""
var _rejection_tween: Tween

const TOOLTIP_OFFSET := Vector2(10, 10)


func _ready() -> void:
  _setup_custom_tooltip()
  set_process(false)
  mouse_entered.connect(_on_mouse_entered)
  mouse_exited.connect(hide_tooltip)


func _setup_custom_tooltip() -> void:
  _tooltip_panel = PanelContainer.new()
  _tooltip_panel.name = "CustomTooltip"
  _tooltip_panel.top_level = true
  _tooltip_panel.visible = false
  _tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _tooltip_panel.z_index = 100

  _tooltip_label = Label.new()
  _tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  _tooltip_label.custom_minimum_size = Vector2(200, 0)
  _tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

  _tooltip_panel.add_child(_tooltip_label)
  add_child(_tooltip_panel)


func _on_mouse_entered() -> void:
  # Click audio is chosen by the hotbar after checking whether placement is allowed.
  AudioManager.play_sound_2d(Resource_SoundEffect.SoundEffect.UI_HOVER)
  if _custom_tooltip_text.is_empty():
    return
  _tooltip_label.text = _custom_tooltip_text
  _update_tooltip_position()
  _tooltip_panel.visible = true
  set_process(true)


func hide_tooltip() -> void:
  _tooltip_panel.visible = false
  set_process(false)


## A small, pause-safe shake that does not fight the slot container's layout.
func show_rejection_feedback() -> void:
  if _rejection_tween and _rejection_tween.is_running():
    return
  pivot_offset = size / 2.0
  _rejection_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
  _rejection_tween.tween_property(self, "rotation", -0.06, 0.05)
  _rejection_tween.tween_property(self, "rotation", 0.06, 0.07)
  _rejection_tween.tween_property(self, "rotation", -0.03, 0.05)
  _rejection_tween.tween_property(self, "rotation", 0.0, 0.05)


func stop_rejection_feedback() -> void:
  if _rejection_tween:
    _rejection_tween.kill()
  rotation = 0.0


func _notification(what: int) -> void:
  if what == NOTIFICATION_VISIBILITY_CHANGED:
    if not is_visible_in_tree() and is_instance_valid(_tooltip_panel):
      _tooltip_panel.visible = false


func _process(_delta: float) -> void:
  _update_tooltip_position()


func _update_tooltip_position() -> void:
  var mouse_pos := get_global_mouse_position()
  var viewport_rect := get_viewport_rect()
  var tooltip_size := _tooltip_panel.get_combined_minimum_size()
  var pos := mouse_pos + TOOLTIP_OFFSET
  if pos.x + tooltip_size.x > viewport_rect.size.x:
    pos.x = mouse_pos.x - tooltip_size.x - TOOLTIP_OFFSET.x
  if pos.y + tooltip_size.y > viewport_rect.size.y:
    pos.y = mouse_pos.y - tooltip_size.y - TOOLTIP_OFFSET.y
  var max_x: float = max(0.0, viewport_rect.size.x - tooltip_size.x)
  var max_y: float = max(0.0, viewport_rect.size.y - tooltip_size.y)
  pos.x = clamp(pos.x, 0.0, max_x)
  pos.y = clamp(pos.y, 0.0, max_y)
  _tooltip_panel.global_position = pos


## Load the building data into the button
func load(slot_index: int, building: Resource_BuildingType) -> void:
  if building:
    # Set button icon and custom tooltip text
    self.icon = building.icon if building.icon else null
    _custom_tooltip_text = "%s\nCost: %d\n%s\n\nLeft click: Select\nRight click: Choose different building" % [building.name, building.cost, building.description]
    self.disabled = false

    # Show cost and slot number on button
    slot_label.text = "%d" % (slot_index + 1)
    cost_label.text = "$%d" % building.cost
  else:
    # Empty slot
    self.icon = null
    _custom_tooltip_text = "Empty slot %d\n\nRight click to choose a building" % (slot_index + 1)
    self.disabled = true
    slot_label.text = "%d" % (slot_index + 1)
    cost_label.text = ""
