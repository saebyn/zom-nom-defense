extends Control

class_name UI_PlaySelect

signal mode_activated(mode_id: StringName)

const MAIN_MENU_SCENE := "res://Stages/UI/main_menu/main_menu.tscn"
const SCENARIO_SELECT_SCENE := "res://Stages/UI/scenario_select/scenario_select.tscn"
const MODE_CAMPAIGN := &"campaign"

@onready var _campaign_card = %CampaignCard
@onready var _challenge_card = %ChallengeCard
@onready var _endless_card = %EndlessCard
@onready var _back_button: BaseButton = %BackButton

var _selected_mode := MODE_CAMPAIGN
var _mode_cards: Dictionary = {}

func _ready() -> void:
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  get_tree().paused = false

  _mode_cards = {
    MODE_CAMPAIGN: _campaign_card,
    &"challenge": _challenge_card,
    &"endless": _endless_card,
  }

  for mode_id in _mode_cards:
    var card = _mode_cards[mode_id]
    card.selection_requested.connect(_on_mode_selection_requested)

  _back_button.pressed.connect(_return_to_main_menu)
  _set_selected_mode(MODE_CAMPAIGN)
  _campaign_card.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed("ui_accept"):
    if _mode_card_has_focus():
      _activate_selected_mode()
      get_viewport().set_input_as_handled()
  elif event.is_action_pressed("ui_cancel"):
    _return_to_main_menu()
    get_viewport().set_input_as_handled()

func get_selected_mode() -> StringName:
  return _selected_mode

func _on_mode_selection_requested(mode_id: StringName) -> void:
  _set_selected_mode(mode_id)
  if _selected_mode == mode_id:
    _activate_selected_mode()

func _set_selected_mode(mode_id: StringName) -> void:
  if not _mode_cards.has(mode_id):
    return

  var card = _mode_cards[mode_id]
  if card.temporarily_disabled:
    return

  _selected_mode = mode_id
  for candidate_id in _mode_cards:
    var candidate = _mode_cards[candidate_id]
    candidate.selected = candidate_id == _selected_mode

func _activate_selected_mode() -> void:
  if _selected_mode == MODE_CAMPAIGN:
    mode_activated.emit(_selected_mode)
    _change_scene(SCENARIO_SELECT_SCENE)

func _mode_card_has_focus() -> bool:
  var focus_owner := get_viewport().gui_get_focus_owner()
  for card in _mode_cards.values():
    if focus_owner == card:
      return true
  return false

func _return_to_main_menu() -> void:
  _change_scene(MAIN_MENU_SCENE)

func _change_scene(scene_path: String) -> void:
  var error := get_tree().change_scene_to_file(scene_path)
  if error != OK:
    MyLogger.error("PlaySelect", "Failed to load scene: %s (Error: %d)" % [scene_path, error])
