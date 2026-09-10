@tool
extends Button

class_name UI_PlayModeCard

signal selection_requested(card_id: StringName)

@export var card_id: StringName = &""
@export var title_text := "MODE":
  set(value):
    title_text = value
    _refresh()
@export_multiline var description_text := "Mode description.":
  set(value):
    description_text = value
    _refresh()
@export var artwork: Texture2D:
  set(value):
    artwork = value
    _refresh()
@export var artwork_source_region := Rect2():
  set(value):
    artwork_source_region = value
    _refresh_artwork_texture()
@export var selected := false:
  set(value):
    selected = value
    _refresh()
@export var temporarily_disabled := false:
  set(value):
    temporarily_disabled = value
    _refresh()
@export var disabled_reason := "Temporarily unavailable":
  set(value):
    disabled_reason = value
    _refresh()

@onready var _artwork_rect: TextureRect = %Artwork
@onready var _artwork_dim: ColorRect = %ArtworkDim
@onready var _surface: NinePatchRect = %Surface
@onready var _title_label: Label = %Title
@onready var _description_label: Label = %Description
@onready var _status_label: Label = %Status
@onready var _selected_ribbon: TextureRect = %SelectedRibbon
@onready var _focus_frame: NinePatchRect = %FocusFrame
@onready var _hover_frame: NinePatchRect = %HoverFrame

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
  if not focus_entered.is_connected(_refresh_navigation_frames):
    focus_entered.connect(_refresh_navigation_frames)
  if not focus_exited.is_connected(_refresh_navigation_frames):
    focus_exited.connect(_refresh_navigation_frames)
  _ignore_mouse_on_children(self)
  _refresh()

func _refresh() -> void:
  if not is_node_ready():
    return

  _refresh_artwork_texture()
  _title_label.text = title_text.to_upper()
  _description_label.text = description_text
  _status_label.text = "UNAVAILABLE" if temporarily_disabled else "READY"
  _selected_ribbon.visible = selected
  _artwork_dim.visible = temporarily_disabled
  _artwork_rect.modulate = Color(0.86, 0.84, 0.76, 0.9) if temporarily_disabled else Color.WHITE
  _title_label.modulate = Color(0.62, 0.60, 0.54, 0.95) if temporarily_disabled else Color.WHITE
  _description_label.modulate = Color(0.62, 0.60, 0.54, 0.85) if temporarily_disabled else Color.WHITE
  tooltip_text = disabled_reason if temporarily_disabled else ""
  disabled = temporarily_disabled
  focus_mode = Control.FOCUS_NONE if temporarily_disabled else Control.FOCUS_ALL
  _refresh_navigation_frames()

func apply_preview_navigation_state(hovered: bool, focused: bool) -> void:
  _uses_preview_navigation_state = true
  _preview_hovered = hovered
  _preview_focused = focused
  _refresh_navigation_frames()

func _on_pressed() -> void:
  if temporarily_disabled:
    return
  selection_requested.emit(card_id)

func _on_mouse_entered() -> void:
  _hovered = true
  _refresh_navigation_frames()

func _on_mouse_exited() -> void:
  _hovered = false
  _refresh_navigation_frames()

func _refresh_navigation_frames() -> void:
  if not is_node_ready():
    return

  var is_focused := _preview_focused if _uses_preview_navigation_state else has_focus()
  var is_hovered := _preview_hovered if _uses_preview_navigation_state else _hovered
  var shows_focus := is_focused and not temporarily_disabled
  var shows_hover := is_hovered and not shows_focus and not temporarily_disabled
  _surface.visible = not shows_focus
  _focus_frame.visible = shows_focus
  _hover_frame.visible = shows_hover

func _refresh_artwork_texture() -> void:
  if not is_node_ready():
    return

  if artwork == null:
    _artwork_rect.texture = null
    return

  if artwork_source_region == Rect2():
    _artwork_rect.texture = artwork
    return

  var source_region := artwork_source_region
  if source_region.size == Vector2.ZERO:
    source_region.size = artwork.get_size()

  var cropped_artwork := AtlasTexture.new()
  cropped_artwork.atlas = artwork
  cropped_artwork.region = source_region
  _artwork_rect.texture = cropped_artwork

func _ignore_mouse_on_children(node: Node) -> void:
  for child in node.get_children():
    if child is Control:
      child.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ignore_mouse_on_children(child)
