extends Control
class_name UI_TechTree

## Tech Tree UI Screen
## Displays tech nodes as a visual tree, allows players to unlock techs,
## and shows mutually exclusive warnings
const TechNodeCardScene = preload("res://Stages/UI/tech_tree/tech_node_card.tscn")

@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var tech_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/TechGrid
@onready var detail_panel: Panel = $Panel/MarginContainer/VBoxContainer/DetailPanel
@onready var detail_name: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/VBoxContainer/NameLabel
@onready var detail_description: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var detail_requirements: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/VBoxContainer/RequirementsLabel
@onready var detail_unlocks: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/VBoxContainer/UnlocksLabel
@onready var unlock_button: Button = $Panel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/VBoxContainer/UnlockButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CloseButton
@onready var confirmation_dialog: ConfirmationDialog = $ConfirmationDialog

var selected_tech_id: String = ""
var tech_node_cards: Dictionary = {} # tech_id -> UI_TechNodeCard

func _ready() -> void:
  # Connect to GameManager state changes
  GameManager.game_state_changed.connect(_on_game_state_changed)

  # Connect to TechTreeManager signals
  TechTreeManager.tech_unlocked.connect(_on_tech_unlocked)
  TechTreeManager.tech_locked.connect(_on_tech_locked)
  
  # Connect UI signals
  close_button.pressed.connect(_on_close_pressed)
  unlock_button.pressed.connect(_on_unlock_button_pressed)
  confirmation_dialog.confirmed.connect(_on_confirmation_accepted)
  
  # Hide detail panel initially
  detail_panel.visible = false
  
  # Refresh the tech tree display
  _refresh_tech_tree()
  
  MyLogger.info("TechTree", "Tech Tree UI initialized")

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
  match new_state:
    GameManager.GameState.IN_TECH_TREE:
      visible = true
      # Refresh card states to reflect any scrap/level changes since last open
      for tech_id in tech_node_cards:
        _update_tech_node_card(tech_id)
      _update_detail_panel()
      # Focus the close button for keyboard navigation
      close_button.grab_focus()
    GameManager.GameState.PLAYING:
      visible = false

## Handle unhandled key inputs (ESC to close)
func _unhandled_key_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed and not event.echo:
    if event.keycode == KEY_ESCAPE:
      _on_close_pressed()
      accept_event()

## Refresh the entire tech tree display
func _refresh_tech_tree() -> void:
  # Clear existing cards
  for child in tech_grid.get_children():
    child.queue_free()
  tech_node_cards.clear()
  
  # Group techs by branch
  var branches = {
    "Offensive": [],
    "Defensive": [],
    "Economy": [],
    "Support": [],
    "Click": [],
    "Advanced": []
  }
  
  # Categorize all tech nodes
  for tech_id in TechTreeManager.tech_nodes:
    var tech = TechTreeManager.tech_nodes[tech_id]
    if tech.branch_name in branches:
      branches[tech.branch_name].append(tech)
  
  # Sort each branch by level requirement
  for branch_name in branches:
    branches[branch_name].sort_custom(func(a, b): return a.level_requirement < b.level_requirement)
  
  # Create cards for each branch in order
  for branch_name in ["Offensive", "Defensive", "Economy", "Support", "Click", "Advanced"]:
    if branches[branch_name].size() > 0:
      # Add branch header
      var header = Label.new()
      header.text = "=== %s ===" % branch_name
      header.add_theme_font_size_override("font_size", 20)
      header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
      tech_grid.add_child(header)
      
      # Add tech cards for this branch
      for tech in branches[branch_name]:
        _create_tech_node_card(tech)

## Create a tech node card for the given tech
func _create_tech_node_card(tech: Resource_TechNode) -> void:
  var card = TechNodeCardScene.instantiate()
  tech_grid.add_child(card)
  tech_node_cards[tech.id] = card
  
  # Setup the card
  card.setup(tech)
  card.selected.connect(_on_tech_node_selected.bind(tech.id))
  card.unlock_requested.connect(_on_tech_node_unlock_requested.bind(tech.id))
  
  # Update card state
  _update_tech_node_card(tech.id)

## Update a specific tech node card's state
func _update_tech_node_card(tech_id: String) -> void:
  if tech_id not in tech_node_cards:
    return
  
  var card = tech_node_cards[tech_id]
  var tech = TechTreeManager.tech_nodes[tech_id]
  
  # Determine state
  var state = UI_TechNodeCard.NodeState.LOCKED
  if TechTreeManager.is_tech_unlocked(tech_id):
    state = UI_TechNodeCard.NodeState.UNLOCKED
  elif TechTreeManager.is_tech_locked(tech_id):
    state = UI_TechNodeCard.NodeState.PERMANENTLY_LOCKED
  elif TechTreeManager.can_unlock_tech(tech_id):
    state = UI_TechNodeCard.NodeState.AVAILABLE
  
  card.update_state(state)

## Handle tech node selection
func _on_tech_node_selected(tech_id: String) -> void:
  selected_tech_id = tech_id
  _update_detail_panel()

## Handle tech node unlock request (double-click)
func _on_tech_node_unlock_requested(tech_id: String) -> void:
  # Set as selected first
  selected_tech_id = tech_id
  _update_detail_panel()
  
  # Trigger the same unlock logic as the unlock button
  _attempt_unlock(tech_id)

## Update the detail panel with selected tech info
func _update_detail_panel() -> void:
  if selected_tech_id.is_empty() or selected_tech_id not in TechTreeManager.tech_nodes:
    detail_panel.visible = false
    return
  
  var tech = TechTreeManager.tech_nodes[selected_tech_id]
  detail_panel.visible = true
  
  # Update labels
  detail_name.text = tech.display_name
  detail_description.text = tech.description
  
  # Build requirements text
  var requirements_text = "Requirements:\n"
  requirements_text += "• Level %d" % tech.level_requirement
  if tech.scrap_cost > 0:
    requirements_text += "\n• %d Scrap" % tech.scrap_cost
  if tech.prerequisite_tech_ids.size() > 0:
    requirements_text += "\n• Prerequisites:"
    for prereq_id in tech.prerequisite_tech_ids:
      var prereq = TechTreeManager.get_tech_node(prereq_id)
      if prereq:
        requirements_text += "\n  - %s" % prereq.display_name
  if tech.requires_branch_completion.size() > 0:
    requirements_text += "\n• Complete branches: %s" % ", ".join(tech.requires_branch_completion)
  detail_requirements.text = requirements_text
  
  var building_names := PackedStringArray()
  for building_type in BuildingRegistry.get_buildings_requiring_tech(tech.id):
    building_names.append(building_type.name)
  building_names.sort()

  var unlocks := PackedStringArray()
  if not building_names.is_empty():
    unlocks.append("• Buildings: %s" % ", ".join(building_names))
  if tech.player_attack_effect:
    unlocks.append("• Click upgrade")
  detail_unlocks.visible = not unlocks.is_empty()
  detail_unlocks.text = "Unlocks:\n%s" % "\n".join(unlocks)
  
  # Update unlock button
  if TechTreeManager.is_tech_unlocked(selected_tech_id):
    unlock_button.text = "Already Unlocked"
    unlock_button.disabled = true
  elif TechTreeManager.is_tech_locked(selected_tech_id):
    unlock_button.text = "Permanently Locked"
    unlock_button.disabled = true
    # Show what locked this
    var locked_by = _find_what_locked_tech(selected_tech_id)
    if locked_by:
      detail_requirements.text += "\n\n⛔ Locked by: %s" % locked_by
  elif TechTreeManager.can_unlock_tech(selected_tech_id):
    unlock_button.text = "Unlock"
    unlock_button.disabled = false
  else:
    unlock_button.text = "Cannot Unlock"
    unlock_button.disabled = true

## Find what tech locked this one
func _find_what_locked_tech(tech_id: String) -> String:
  for other_id in TechTreeManager.unlocked_tech_ids:
    var other_tech = TechTreeManager.get_tech_node(other_id)
    if other_tech and tech_id in other_tech.mutually_exclusive_with:
      return other_tech.display_name
  return ""

## Handle unlock button press
func _on_unlock_button_pressed() -> void:
  _attempt_unlock(selected_tech_id)

## Attempt to unlock a tech, handling mutually exclusive checks
func _attempt_unlock(tech_id: String) -> void:
  if tech_id.is_empty() or tech_id not in TechTreeManager.tech_nodes:
    return
  
  var tech = TechTreeManager.tech_nodes[tech_id]
  
  # Check for mutually exclusive techs
  if tech.mutually_exclusive_with.size() > 0:
    _show_exclusive_warning(tech)
  else:
    _unlock_tech(tech_id)

## Show confirmation dialog for mutually exclusive choices
func _show_exclusive_warning(tech: Resource_TechNode) -> void:
  var locked_names = []
  for exclusive_id in tech.mutually_exclusive_with:
    if exclusive_id in TechTreeManager.tech_nodes:
      locked_names.append(TechTreeManager.tech_nodes[exclusive_id].display_name)
  
  var message = "Unlocking '%s' will permanently lock:\n\n" % tech.display_name
  for name in locked_names:
    message += "  • %s\n" % name
  message += "\nThis cannot be undone. Continue?"
  
  confirmation_dialog.dialog_text = message
  confirmation_dialog.popup_centered()

## Handle confirmation dialog acceptance
func _on_confirmation_accepted() -> void:
  _unlock_tech(selected_tech_id)

## Actually unlock the tech
func _unlock_tech(tech_id: String) -> void:
  if TechTreeManager.unlock_tech(tech_id):
    if GameManager.current_state == GameManager.GameState.MAIN_MENU:
      SaveManager.save_menu_tech_choices()
    MyLogger.info("TechTree", "Successfully unlocked tech: %s" % tech_id)
    # UI will update via signals
  else:
    MyLogger.warn("TechTree", "Failed to unlock tech: %s" % tech_id)

## Handle tech unlocked signal
func _on_tech_unlocked(tech_id: String) -> void:
  MyLogger.debug("TechTree", "Tech unlocked: %s" % tech_id)
  _update_tech_node_card(tech_id)
  _update_detail_panel()

## Handle tech locked signal
func _on_tech_locked(tech_id: String) -> void:
  MyLogger.debug("TechTree", "Tech locked: %s" % tech_id)
  _update_tech_node_card(tech_id)
  if selected_tech_id == tech_id:
    _update_detail_panel()

## Handle close button
func _on_close_pressed() -> void:
  MyLogger.info("TechTree", "Closing Tech Tree UI")
  if GameManager.current_state == GameManager.GameState.IN_TECH_TREE:
    GameManager.set_game_state(GameManager.GameState.PLAYING)
