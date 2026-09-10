@tool
extends Button

class_name UI_MenuCard

## One focusable menu choice with composable choice, availability, and progression states.

signal selection_requested(card_id: StringName)
signal locked_inspected(card_id: StringName)

@export_group("Content")
@export var card_id: StringName = &""
@export var card_number := "01":
  set(value):
    card_number = value
    _refresh()
@export var title_text := "MENU CARD":
  set(value):
    title_text = value
    _refresh()
@export_multiline var description_text := "A representative menu card.":
  set(value):
    description_text = value
    _refresh()
@export var action_label := "AVAILABLE":
  set(value):
    action_label = value
    _refresh()
@export var artwork: Texture2D:
  set(value):
    artwork = value
    _refresh()

@export_group("Choice")
@export var selected := false:
  set(value):
    selected = value
    _refresh()

@export_group("Availability")
@export var locked := false:
  set(value):
    locked = value
    _refresh()
@export var lock_reason := "Complete the previous Scenario":
  set(value):
    lock_reason = value
    _refresh()
@export var temporarily_disabled := false:
  set(value):
    temporarily_disabled = value
    _refresh()
@export var disabled_reason := "Temporarily unavailable":
  set(value):
    disabled_reason = value
    _refresh()

@export_group("Progression")
@export var completed := false:
  set(value):
    completed = value
    _refresh()

@onready var _number_label: Label = %Number
@onready var _title_label: Label = %Title
@onready var _description_label: Label = %Description
@onready var _status_label: Label = %Status
@onready var _status_plate: NinePatchRect = %StatusPlate
@onready var _artwork_frame: PanelContainer = %ArtworkFrame
@onready var _artwork_rect: TextureRect = %Artwork
@onready var _artwork_placeholder: Control = %ArtworkPlaceholder
@onready var _artwork_dim: ColorRect = %ArtworkDim
@onready var _lock_overlay: Control = %LockOverlay
@onready var _selection_marker: Control = %SelectionMarker
@onready var _completion_badge: Control = %CompletionBadge
@onready var _base_surface: Control = %BaseSurface
@onready var _card_frame: NinePatchRect = %CardFrame
@onready var _hover_frame: NinePatchRect = %HoverFrame
@onready var _focus_frame: NinePatchRect = %FocusFrame
@onready var _title_stack: BoxContainer = %TitleStack
@onready var _content_margin: MarginContainer = %ContentMargin
@onready var _card_body: BoxContainer = %CardBody
@onready var _info_area: BoxContainer = %InfoArea

var _hovered := false
var _uses_preview_navigation_state := false
var _preview_hovered := false
var _preview_focused := false

func _ready() -> void:
  if not pressed.is_connected(_on_pressed):
    pressed.connect(_on_pressed)
  if not mouse_entered.is_connected(_on_mouse_entered):
    mouse_entered.connect(_on_mouse_entered)
  if not mouse_exited.is_connected(_on_mouse_exited):
    mouse_exited.connect(_on_mouse_exited)
  if not focus_entered.is_connected(_on_focus_changed):
    focus_entered.connect(_on_focus_changed)
  if not focus_exited.is_connected(_on_focus_changed):
    focus_exited.connect(_on_focus_changed)
  _ignore_mouse_on_children(self)
  _refresh()

func _refresh() -> void:
  if not is_node_ready():
    return

  _number_label.text = card_number
  _title_label.text = _format_title_text(title_text.to_upper())
  _description_label.text = _format_description_text(description_text)

  _artwork_rect.texture = artwork
  _artwork_rect.visible = artwork != null
  _artwork_placeholder.visible = artwork == null
  _artwork_dim.visible = locked or temporarily_disabled

  _selection_marker.visible = selected
  _completion_badge.visible = completed
  _lock_overlay.visible = locked and not temporarily_disabled
  tooltip_text = _get_tooltip_text()
  _refresh_layout()
  _refresh_artwork_frame()

  disabled = temporarily_disabled
  focus_mode = Control.FOCUS_NONE if temporarily_disabled else Control.FOCUS_ALL
  _status_label.text = _get_status_text()
  _refresh_content_dimming()
  _refresh_navigation_frames()

func _get_status_text() -> String:
  if temporarily_disabled:
    return "UNAVAILABLE"
  if locked:
    return _get_lock_status_text()
  if completed:
    return "COMPLETED"
  if selected:
    return "SELECTED"
  return action_label.to_upper()

func _get_tooltip_text() -> String:
  if temporarily_disabled:
    return disabled_reason
  if locked:
    return lock_reason
  return ""

func _get_lock_status_text() -> String:
  if lock_reason.is_empty():
    return "LOCKED"
  return _format_description_text(lock_reason.to_upper())

func _format_title_text(text: String) -> String:
  if text.length() <= 14 or not text.contains(" "):
    return text

  return _break_at_middle_space(text)

func _format_description_text(text: String) -> String:
  if text.length() <= 34 or not text.contains(" "):
    return text

  return _break_at_middle_space(text)

func _break_at_middle_space(text: String) -> String:
  if not text.contains(" "):
    return text

  var target_index := text.length() / 2.0
  var best_space_index := -1
  var best_distance := INF
  for index in range(text.length()):
    if text[index] != " ":
      continue

    var distance: float = abs(index - target_index)
    if distance < best_distance:
      best_distance = distance
      best_space_index = index

  if best_space_index == -1:
    return text

  return "%s\n%s" % [text.substr(0, best_space_index), text.substr(best_space_index + 1)]

func _on_pressed() -> void:
  if temporarily_disabled:
    return
  if locked:
    locked_inspected.emit(card_id)
    return
  selection_requested.emit(card_id)

func apply_preview_navigation_state(hovered: bool, focused: bool) -> void:
  _uses_preview_navigation_state = true
  _preview_hovered = hovered
  _preview_focused = focused
  _refresh_navigation_frames()

func _on_mouse_entered() -> void:
  _hovered = true
  _refresh_navigation_frames()

func _on_mouse_exited() -> void:
  _hovered = false
  _refresh_navigation_frames()

func _on_focus_changed() -> void:
  _refresh_navigation_frames()

func _refresh_navigation_frames() -> void:
  var is_focused := _preview_focused if _uses_preview_navigation_state else has_focus()
  var is_hovered := _preview_hovered if _uses_preview_navigation_state else _hovered
  var shows_focus := is_focused and not temporarily_disabled
  var shows_hover := is_hovered and not shows_focus and not temporarily_disabled

  _card_frame.visible = not shows_focus and not shows_hover
  _base_surface.visible = _card_frame.visible
  _hover_frame.visible = shows_hover
  _focus_frame.visible = shows_focus

func _refresh_content_dimming() -> void:
  var dimmed_color := Color(0.78, 0.78, 0.72, 0.9) if locked else Color.WHITE
  if temporarily_disabled:
    dimmed_color = Color(0.86, 0.84, 0.76, 0.9)
  _artwork_placeholder.modulate = dimmed_color
  _artwork_rect.modulate = dimmed_color
  _title_stack.modulate = dimmed_color
  _description_label.modulate = dimmed_color
  _artwork_dim.color = Color(0.075, 0.082, 0.068, 0.24) if temporarily_disabled else Color(0.075, 0.082, 0.068, 0.52)

func _refresh_artwork_frame() -> void:
  if locked:
    _artwork_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
  else:
    _artwork_frame.remove_theme_stylebox_override("panel")

func _refresh_layout() -> void:
  _card_body.vertical = true
  _card_body.add_theme_constant_override("separation", 12)

  _content_margin.add_theme_constant_override("margin_left", 24)
  _content_margin.add_theme_constant_override("margin_top", 36)
  _content_margin.add_theme_constant_override("margin_right", 24)
  _content_margin.add_theme_constant_override("margin_bottom", 32)

  _artwork_frame.custom_minimum_size = Vector2(280, 364)
  _artwork_frame.clip_contents = false
  _artwork_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  _artwork_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  _artwork_frame.size_flags_vertical = Control.SIZE_FILL
  _artwork_frame.size_flags_stretch_ratio = 1.0
  _artwork_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _artwork_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

  _info_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _info_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
  _info_area.size_flags_stretch_ratio = 1.0
  _info_area.add_theme_constant_override("separation", 10)

  _title_stack.vertical = true
  _title_stack.add_theme_constant_override("separation", 2)

  _title_label.custom_minimum_size = Vector2(0, 92)
  _description_label.custom_minimum_size = Vector2(0, 70)
  _status_label.custom_minimum_size = Vector2(0, 64)

  _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _status_plate.visible = true

  _refresh_frame_layout()
  _refresh_selection_marker_layout()

func _refresh_frame_layout() -> void:
  var frame_margin := 72
  for frame in [_card_frame, _hover_frame, _focus_frame]:
    frame.patch_margin_left = frame_margin
    frame.patch_margin_top = frame_margin
    frame.patch_margin_right = frame_margin
    frame.patch_margin_bottom = frame_margin

func _refresh_selection_marker_layout() -> void:
  _selection_marker.anchor_left = 1.0
  _selection_marker.anchor_top = 0.0
  _selection_marker.anchor_right = 1.0
  _selection_marker.anchor_bottom = 0.0
  _selection_marker.offset_left = -92.0
  _selection_marker.offset_top = -18.0
  _selection_marker.offset_right = 12.0
  _selection_marker.offset_bottom = 148.0

func _ignore_mouse_on_children(node: Node) -> void:
  for child in node.get_children():
    if child is Control:
      child.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ignore_mouse_on_children(child)
