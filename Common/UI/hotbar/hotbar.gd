"""
Hotbar.gd

A dynamic hotbar component that displays available building types and allows quick access.
Supports both mouse clicks and keyboard shortcuts for building selection.
Includes configuration capabilities to change which buildings are in which slots.
"""
extends Control
class_name UI_Hotbar

signal building_selected(building: Resource_BuildingType)

const REJECTION_SOUND_COOLDOWN_MS := 350

@export var max_slots: int = 6 # Maximum number of hotbar slots
@export var spacing: int = 8 # Spacing between slots
@export var button_scene: PackedScene # Scene for individual hotbar buttons

@onready var slots_container: HBoxContainer = $SlotsContainer
@onready var building_selection_menu: PopupMenu = $BuildingSelectionMenu
@onready var pause_feedback: PanelContainer = $PauseFeedback
@onready var pause_feedback_timer: Timer = $PauseFeedbackTimer
@onready var rejection_audio: AudioStreamPlayer = $RejectionAudio

var slot_building_ids: Array[String] = [] ## Building IDs for each slot
var slot_buttons: Array[HotbarButton] = [] ## Button references for each slot
var current_configuring_slot: int = -1 ## Track which slot was last right-clicked for configuration (-1 if none, may not be valid index or current if no menu open)
var _last_rejection_sound_ms := -REJECTION_SOUND_COOLDOWN_MS

func _ready() -> void:
  _setup_ui()
  _connect_signals()
  _populate_default_hotbar()
  set_process(false)

func _process(_delta: float) -> void:
  # Only process while the notice is visible, including while gameplay is paused.
  if not GameManager.is_paused() or not _can_show_pause_feedback():
    _hide_pause_feedback()

func _can_show_pause_feedback() -> bool:
  return (GameManager.is_playing() and is_visible_in_tree()
    and not building_selection_menu.visible and not Dialogic.Text.is_textbox_visible())

func _show_pause_feedback(slot_index: int) -> void:
  if not _can_show_pause_feedback():
    return
  # Hover tooltips otherwise cover the notice above the hotbar.
  for button in slot_buttons:
    button.hide_tooltip()
  pause_feedback.show()
  # Reuse one notice and timer; repeated attempts extend it without stacking effects.
  pause_feedback_timer.start()
  slot_buttons[slot_index].show_rejection_feedback()
  var now := Time.get_ticks_msec()
  if now - _last_rejection_sound_ms >= REJECTION_SOUND_COOLDOWN_MS:
    AudioManager.play_sound(rejection_audio, Resource_SoundEffect.SoundEffect.ERROR)
    _last_rejection_sound_ms = now
  set_process(true)

func _hide_pause_feedback() -> void:
  pause_feedback.hide()
  pause_feedback_timer.stop()
  rejection_audio.stop()
  for button in slot_buttons:
    button.stop_rejection_feedback()
  set_process(false)

func _setup_ui() -> void:
  # Create the container if it doesn't exist
  if not slots_container:
    slots_container = HBoxContainer.new()
    slots_container.name = "SlotsContainer"
    add_child(slots_container)
  
  # Set container properties
  slots_container.add_theme_constant_override("separation", spacing)
  
  # Create hotbar slots
  _create_slots()

func _create_slots() -> void:
  # Clear existing slots
  for button in slot_buttons:
    if is_instance_valid(button):
      button.queue_free()
  slot_buttons.clear()
  
  # Create new slots
  for i in range(max_slots):
    var slot_button = button_scene.instantiate() as HotbarButton
    
    # Connect button signals for both left and right click
    slot_button.pressed.connect(_on_slot_pressed.bind(i))
    slot_button.gui_input.connect(_on_slot_gui_input.bind(i))
    
    slots_container.add_child(slot_button)
    slot_buttons.append(slot_button)

func _connect_signals() -> void:
  # Connect to BuildingRegistry for dynamic updates
  if BuildingRegistry:
    BuildingRegistry.building_types_updated.connect(_on_building_types_updated)

func _populate_default_hotbar() -> void:
  """Populate hotbar with default buildings from registry"""
  MyLogger.info("Hotbar", "Populating hotbar with default buildings")
  
  # Initialize the slot_building_ids array
  slot_building_ids.clear()
  
  if BuildingRegistry:
    var available = BuildingRegistry.available_building_types
    for i in range(max_slots):
      if i < available.size():
        slot_building_ids.append(available[i].id)
        MyLogger.info("Hotbar", "Setting slot %d to %s" % [i, available[i].name])
      else:
        slot_building_ids.append("") # Empty slot
  else:
    # Fill with empty slots if registry not available
    for i in range(max_slots):
      slot_building_ids.append("")
  
  # Update all slot visuals
  for i in range(max_slots):
    _update_slot_visual(i)

func _get_building_by_id(building_id: String) -> Resource_BuildingType:
  """Get building resource by ID from the registry"""
  if building_id.is_empty() or not BuildingRegistry:
    return null
  
  for building in BuildingRegistry.available_building_types:
    if building.id == building_id:
      return building
  
  return null

func _update_slot_visual(slot_index: int) -> void:
  """Update the visual representation of a slot"""
  if slot_index >= slot_buttons.size() or slot_index >= slot_building_ids.size():
    return
  
  var button = slot_buttons[slot_index]
  var building_id = slot_building_ids[slot_index]
  var building = _get_building_by_id(building_id)

  button.load(slot_index, building)

func _on_slot_pressed(slot_index: int) -> void:
  """Handle left click on slot - select building for placement"""
  var building = get_slot_building(slot_index)
  # Block world placement when the game is paused (speed = 0 or in-game menu)
  if GameManager.is_paused():
    if building:
      _show_pause_feedback(slot_index)
    return
  
  if building:
    AudioManager.play_sound_2d(Resource_SoundEffect.SoundEffect.UI_CONFIRM)
    MyLogger.info("Hotbar", "Selected building: %s from slot %d" % [building.name, slot_index + 1])
    building_selected.emit(building)

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
  """Handle GUI input for advanced slot interactions"""
  # Block hotbar configuration when the in-game menu is open
  if GameManager.current_state == GameManager.GameState.IN_GAME_MENU:
    return
  
  if event is InputEventMouseButton and event.pressed:
    if event.button_index == MOUSE_BUTTON_RIGHT:
      _show_building_selection_menu(slot_index)

func _show_building_selection_menu(slot_index: int) -> void:
  """Show popup menu with available buildings for slot assignment"""
  if not BuildingRegistry or not building_selection_menu:
    return
  
  var available = BuildingRegistry.available_building_types
  if available.is_empty():
    return
  
  # Remember which slot we're configuring
  current_configuring_slot = slot_index
  
  # Clear existing menu items
  building_selection_menu.clear()
  
  # Add "Clear Slot" option for non-empty slots
  var current_building_id = slot_building_ids[slot_index] if slot_index < slot_building_ids.size() else ""
  if not current_building_id.is_empty():
    building_selection_menu.add_item("Clear Slot", 0)
    building_selection_menu.add_separator()
  
  # Add available buildings to menu
  for i in range(available.size()):
    var building = available[i]
    var item_text = "%s ($%d)" % [building.name, building.cost]
    building_selection_menu.add_item(item_text, i + 1) # +1 to account for "Clear Slot" at index 0
    
    # Set icon if available
    if building.icon:
      building_selection_menu.set_item_icon(building_selection_menu.get_item_count() - 1, building.icon)
    
    # Highlight current selection
    if building.id == current_building_id:
      building_selection_menu.set_item_disabled(building_selection_menu.get_item_count() - 1, false)
      # Mark as current selection in some way - could add checkmark or different styling
  
  # Position menu near the clicked slot button
  var button = slot_buttons[slot_index]
  var button_global_rect = button.get_global_rect()
  var menu_position = Vector2i(button_global_rect.position.x, button_global_rect.position.y + button_global_rect.size.y)
  
  # Show the popup menu
  building_selection_menu.popup_on_parent(Rect2i(menu_position, Vector2i(200, 0)))
  
  MyLogger.info("Hotbar", "Showing building selection menu for slot %d" % (slot_index + 1))

func _on_building_menu_item_selected(id: int) -> void:
  """Handle selection from the building popup menu"""
  if current_configuring_slot < 0:
    MyLogger.warn("Hotbar", "No slot is currently being configured")
    return
  
  if id == 0:
    # Clear slot option selected
    set_slot_building(current_configuring_slot, null)
    MyLogger.info("Hotbar", "Cleared slot %d" % (current_configuring_slot + 1))
  else:
    # Building selected
    var available = BuildingRegistry.available_building_types
    if id <= available.size():
      var selected_building = available[id - 1] # -1 to account for "Clear Slot" at index 0
      set_slot_building(current_configuring_slot, selected_building)
      MyLogger.info("Hotbar", "Assigned %s to slot %d" % [selected_building.name, current_configuring_slot + 1])
  
  # Reset the configuring slot
  current_configuring_slot = -1

func set_slot_building(slot_index: int, building: Resource_BuildingType) -> void:
  """Set a building for a specific slot"""
  if slot_index < 0 or slot_index >= max_slots:
    MyLogger.warn("Hotbar", "Invalid slot index: %d" % slot_index)
    return
  
  # Ensure array is large enough
  while slot_building_ids.size() <= slot_index:
    slot_building_ids.append("")
  
  # Set the building ID
  var building_id = building.id if building else ""
  slot_building_ids[slot_index] = building_id
  
  # Update visual
  _update_slot_visual(slot_index)

func _input(event: InputEvent) -> void:
  # Handle keyboard shortcuts for hotbar slots (1-6)
  if event is InputEventKey and event.pressed and not event.echo:
    for slot_index in range(mini(max_slots, 6)):
      if event.is_action_pressed("hotbar_slot_%d" % (slot_index + 1)):
        _on_slot_pressed(slot_index)
        break

func _on_building_types_updated(added_types: Array[Resource_BuildingType], removed_types: Array[Resource_BuildingType]) -> void:
  MyLogger.info("Hotbar", "Building types updated. Added: %d, Removed: %d" % [added_types.size(), removed_types.size()])

  # Update the hotbar configuration if any of the added or removed types are currently in the hotbar
  # First, if there are any new types added and there are empty slots, fill them with the new types.
  # Then, if there are any removed types that are currently in the hotbar, clear those slots.
  # The reason for this order is that if we clear removed types first,
  # then we might replace them with new types that were just added, which could be confusing.
  var last_visited_slot_index := 0
  for added in added_types:
    for i in range(last_visited_slot_index, max_slots):
      last_visited_slot_index = i
      if slot_building_ids[i].is_empty():
        slot_building_ids[i] = added.id
        MyLogger.info("Hotbar", "Added new building %s to empty slot %d" % [added.name, i + 1])
        break
    
    # If we've filled all slots, we can stop checking for added types
    if last_visited_slot_index == max_slots - 1:
      break

  for removed in removed_types:
    for i in range(max_slots):
      if slot_building_ids[i] == removed.id:
        slot_building_ids[i] = ""
        MyLogger.info("Hotbar", "Removed building %s from slot %d" % [removed.name, i + 1])
  
  # Update visuals for all slots to reflect changes
  for i in range(max_slots):
    _update_slot_visual(i)

func get_slot_building(slot_index: int) -> Resource_BuildingType:
  """Get the building for a specific slot"""
  if slot_index < 0 or slot_index >= slot_building_ids.size():
    return null
  
  var building_id = slot_building_ids[slot_index]
  return _get_building_by_id(building_id)

func clear_slot(slot_index: int) -> void:
  """Clear a specific slot"""
  set_slot_building(slot_index, null)
