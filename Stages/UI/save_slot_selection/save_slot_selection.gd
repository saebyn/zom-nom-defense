extends Control

class_name UI_SaveSlotSelection

## Save slot selection UI that displays available save slots and handles slot management
## Allows players to create new games, load existing saves, and delete save files

@onready var slot_container = $MarginContainer/VBoxContainer/ScrollContainer/SlotContainer
@onready var back_button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var confirm_dialog = $ConfirmDialog

# Save slot card scene to be instantiated for each slot
const SaveSlotCardScene = preload("res://Stages/UI/save_slot_selection/save_slot_card.tscn")

# Number of save slots to display (using SaveManager's MAX_SAVE_SLOTS, minimum 3)
const NUM_SLOTS = 3 # Can be increased up to SaveManager.MAX_SAVE_SLOTS

# Slot number pending deletion (for confirmation dialog)
var pending_delete_slot: int = -1

func _ready():
  # Set the game state
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)
  MyLogger.info("SaveSlotSelection", "Save slot selection screen loaded")
  
  # Make sure the game is not paused
  get_tree().paused = false
  
  # Populate slot list
  _populate_slots()

## Populate the slot container with save slot cards
func _populate_slots():
  # Clear existing children (if any)
  for child in slot_container.get_children():
    child.queue_free()
  
  # Create cards for each slot
  for slot_num in range(1, NUM_SLOTS + 1):
    var slot_card = SaveSlotCardScene.instantiate()
    slot_container.add_child(slot_card)
    
    # Get metadata for this slot
    var metadata = SaveManager.get_slot_metadata(slot_num)
    
    # Configure the card
    slot_card.configure(slot_num, metadata)
    
    # Connect signals
    slot_card.slot_selected.connect(_on_slot_selected)
    slot_card.slot_deleted.connect(_on_slot_delete_requested)

## Handle slot selection (New Game or Continue)
func _on_slot_selected(slot_number: int):
  var metadata = SaveManager.get_slot_metadata(slot_number)
  var is_occupied = metadata.get("exists", false)
  var is_corrupted = metadata.get("corrupted", false)
  
  if is_corrupted:
    # Create new game in corrupted slot (overwriting it)
    MyLogger.info("SaveSlotSelection", "Creating new game in corrupted slot %d" % slot_number)
    _create_new_game(slot_number)
  elif is_occupied:
    # Load existing save
    MyLogger.info("SaveSlotSelection", "Loading existing save from slot %d" % slot_number)
    _load_game(slot_number)
  else:
    # Create new game
    MyLogger.info("SaveSlotSelection", "Creating new game in slot %d" % slot_number)
    _create_new_game(slot_number)

## Create a new game in the specified slot
func _create_new_game(slot_number: int):
  if not SaveManager.create_new_game(slot_number):
    return

  # Set default scenario
  ScenarioManager.set_current_scenario_id("scenario_1")
  
  # Transition to game
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Load the main game scene
  var game_scene_path = "res://Stages/Game/main/main.tscn"
  MyLogger.info("SaveSlotSelection", "Loading game scene: %s" % game_scene_path)
  
  var error = get_tree().change_scene_to_file(game_scene_path)
  if error != OK:
    MyLogger.error("SaveSlotSelection", "Failed to load game scene: %s (Error: %d)" % [game_scene_path, error])

## Load an existing game from the specified slot
func _load_game(slot_number: int):
  # Load save from SaveManager
  var success = SaveManager.load_save_slot(slot_number)
  
  if not success:
    MyLogger.error("SaveSlotSelection", "Failed to load save slot %d" % slot_number)
    # Show error dialog (for now just log it)
    return
  
  # Save loaded successfully - return to main menu
  # The save data is now loaded, but we don't auto-start the game.
  # This gives users a chance to verify the loaded data or access other menu options before starting gameplay.
  MyLogger.info("SaveSlotSelection", "Save slot %d loaded successfully - returning to main menu" % slot_number)
  
  var main_menu_path = "res://Stages/UI/main_menu/main_menu.tscn"
  var error = get_tree().change_scene_to_file(main_menu_path)
  if error != OK:
    MyLogger.error("SaveSlotSelection", "Failed to load main menu: %s (Error: %d)" % [main_menu_path, error])

## Handle delete button press - show confirmation dialog
func _on_slot_delete_requested(slot_number: int):
  MyLogger.info("SaveSlotSelection", "Delete requested for slot %d" % slot_number)
  
  # Store the slot number for the confirmation callback
  pending_delete_slot = slot_number
  
  # Update dialog text with slot number
  confirm_dialog.dialog_text = "Are you sure you want to delete save slot %d? This action cannot be undone." % slot_number
  
  # Show confirmation dialog
  confirm_dialog.popup_centered()

## Handle delete confirmation
func _on_delete_confirmed():
  if pending_delete_slot < 1:
    MyLogger.warn("SaveSlotSelection", "Delete confirmed but no pending slot")
    return
  
  MyLogger.info("SaveSlotSelection", "Deleting slot %d" % pending_delete_slot)
  
  # Delete the slot
  var success = SaveManager.delete_save_slot(pending_delete_slot)
  
  if success:
    MyLogger.info("SaveSlotSelection", "Successfully deleted slot %d" % pending_delete_slot)
    # Refresh the slot list to update UI
    _populate_slots()
  else:
    MyLogger.error("SaveSlotSelection", "Failed to delete slot %d" % pending_delete_slot)
  
  # Clear pending delete
  pending_delete_slot = -1

## Handle back button press - return to main menu
func _on_back_button_pressed():
  MyLogger.info("SaveSlotSelection", "Back button pressed - returning to main menu")
  var main_menu_path = "res://Stages/UI/main_menu/main_menu.tscn"
  var error = get_tree().change_scene_to_file(main_menu_path)
  if error != OK:
    MyLogger.error("SaveSlotSelection", "Failed to load main menu: %s (Error: %d)" % [main_menu_path, error])
