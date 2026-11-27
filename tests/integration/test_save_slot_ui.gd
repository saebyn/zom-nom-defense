extends GutTest

## Integration tests for Save Slot Selection UI
## Tests slot display, selection, deletion, and navigation

# Test slot range (using a smaller range than SaveManager.MAX_SAVE_SLOTS for faster tests)
const TEST_SLOT_COUNT = 3

func before_each():
  # Clean up any existing test save files
  for slot_num in range(1, TEST_SLOT_COUNT + 1):
    SaveManager.delete_save_slot(slot_num)
  
  # Reset SaveManager state
  SaveManager.current_save_slot = -1

func after_each():
  # Clean up test saves
  for slot_num in range(1, TEST_SLOT_COUNT + 1):
    SaveManager.delete_save_slot(slot_num)
  
  SaveManager.current_save_slot = -1

## Test that the save slot selection scene loads correctly
func test_scene_loads():
  var scene = load("res://Stages/UI/save_slot_selection/save_slot_selection.tscn")
  assert_not_null(scene, "Save slot selection scene should load")
  
  var instance = scene.instantiate()
  assert_not_null(instance, "Save slot selection scene should instantiate")
  
  add_child_autofree(instance)
  await wait_process_frames(1)
  
  # Check that key components exist
  assert_true(instance.has_node("MarginContainer/VBoxContainer/ScrollContainer/SlotContainer"),
              "Slot container should exist")
  assert_true(instance.has_node("MarginContainer/VBoxContainer/TopBar/BackButton"),
              "Back button should exist")
  assert_true(instance.has_node("ConfirmDialog"),
              "Confirm dialog should exist")

## Test that empty slots display correctly
func test_empty_slots_display():
  var scene = load("res://Stages/UI/save_slot_selection/save_slot_selection.tscn")
  var instance = scene.instantiate()
  add_child_autofree(instance)
  await wait_process_frames(2)
  
  var slot_container = instance.get_node("MarginContainer/VBoxContainer/ScrollContainer/SlotContainer")
  var slot_cards = slot_container.get_children()
  
  assert_eq(slot_cards.size(), 3, "Should display 3 save slots")
  
  # Check first slot card
  var first_card = slot_cards[0]
  assert_eq(first_card.slot_number, 1, "First card should be slot 1")
  assert_false(first_card.is_occupied, "First card should be empty")

## Test that occupied slots display metadata correctly
func test_occupied_slots_display():
  # Create a test save in slot 1
  SaveManager.create_new_game(1)
  await wait_process_frames(1)
  
  var scene = load("res://Stages/UI/save_slot_selection/save_slot_selection.tscn")
  var instance = scene.instantiate()
  add_child_autofree(instance)
  await wait_process_frames(2)
  
  var slot_container = instance.get_node("MarginContainer/VBoxContainer/ScrollContainer/SlotContainer")
  var slot_cards = slot_container.get_children()
  
  assert_eq(slot_cards.size(), 3, "Should display 3 save slots")
  
  # Check first slot card (should be occupied)
  var first_card = slot_cards[0]
  assert_eq(first_card.slot_number, 1, "First card should be slot 1")
  assert_true(first_card.is_occupied, "First card should be occupied")

func test_continue_loads_backup_when_primary_is_unusable(
  primary_text = use_parameters(["not JSON", '{"version":1,"metadata":[]}', null])
):
  const SLOT := 2
  SaveManager.create_new_game(SLOT)
  var backup := FileAccess.open(SaveManager.SAVE_SLOT_BACKUP_PATH % SLOT, FileAccess.WRITE)
  backup.store_string(JSON.stringify({
    "version": 1,
    "metadata": {"player_level": 4, "timestamp": 1700000000},
    "player_progression": {"current_level": 4, "current_xp": 37},
  }))
  backup.close()
  var primary_path := SaveManager.SAVE_SLOT_PATH % SLOT
  if primary_text == null:
    assert_eq(DirAccess.remove_absolute(primary_path), OK)
  else:
    var primary := FileAccess.open(primary_path, FileAccess.WRITE)
    primary.store_string(primary_text)
    primary.close()
  SaveManager.create_new_game(SaveManager.DEFAULT_SLOT)

  var picker = load("res://Stages/UI/save_slot_selection/save_slot_selection.tscn").instantiate()
  add_child_autofree(picker)
  var cards = picker.get_node("MarginContainer/VBoxContainer/ScrollContainer/SlotContainer")
  var card = cards.get_child(SLOT - 1)
  var action_button: Button = card.get_node("MarginContainer/HBoxContainer/ButtonContainer/ActionButton")
  assert_eq(action_button.text, "Continue", "A valid backup makes the slot playable")
  if action_button.text != "Continue":
    return
  var info_label: Label = card.get_node("MarginContainer/HBoxContainer/LeftContainer/SlotInfoLabel")
  assert_eq(info_label.text, "Level 4", "The preview shows the backed-up Player Level")

  action_button.pressed.emit()
  assert_eq(CurrencyManager.get_xp(), 37, "Continue loads the backed-up progression")
  await wait_process_frames(2)
  var menu := get_tree().current_scene as UI_MainMenu
  assert_not_null(menu)
  if menu:
    var save_slot_button := menu.get_node("CurrentSave") as Button
    assert_eq(save_slot_button.text, "Save Slot 2")
    assert_eq(SaveManager.current_save_slot, SLOT)
    get_tree().unload_current_scene()
  CurrencyManager.reset_data()

## Test save slot card scene loads
func test_slot_card_loads():
  var scene = load("res://Stages/UI/save_slot_selection/save_slot_card.tscn")
  assert_not_null(scene, "Save slot card scene should load")
  
  var instance = scene.instantiate()
  assert_not_null(instance, "Save slot card scene should instantiate")
  
  add_child_autofree(instance)
  await wait_process_frames(1)
  
  # Check that key components exist
  assert_true(instance.has_node("MarginContainer/HBoxContainer/LeftContainer/SlotNameLabel"),
              "Slot name label should exist")
  assert_true(instance.has_node("MarginContainer/HBoxContainer/ButtonContainer/ActionButton"),
              "Action button should exist")

## Test that slot card configures correctly for empty slot
func test_slot_card_configure_empty():
  var scene = load("res://Stages/UI/save_slot_selection/save_slot_card.tscn")
  var instance = scene.instantiate()
  add_child_autofree(instance)
  await wait_process_frames(1)
  
  # Configure as empty slot
  var metadata = {"exists": false, "slot_number": 1}
  instance.configure(1, metadata)
  
  assert_eq(instance.slot_number, 1, "Slot number should be set")
  assert_false(instance.is_occupied, "Should not be occupied")
  
  var action_button = instance.get_node("MarginContainer/HBoxContainer/ButtonContainer/ActionButton")
  assert_eq(action_button.text, "New Game", "Action button should say 'New Game'")

## Test that slot card configures correctly for occupied slot
func test_slot_card_configure_occupied():
  var scene = load("res://Stages/UI/save_slot_selection/save_slot_card.tscn")
  var instance = scene.instantiate()
  add_child_autofree(instance)
  await wait_process_frames(1)
  
  # Configure as occupied slot
  var metadata = {
    "exists": true,
    "slot_number": 1,
    "player_level": 5,
    "playtime": 3600.0, # 1 hour
    "timestamp": Time.get_unix_time_from_system(),
    "last_scenario": "scenario_1"
  }
  instance.configure(1, metadata)
  
  assert_eq(instance.slot_number, 1, "Slot number should be set")
  assert_true(instance.is_occupied, "Should be occupied")
  
  var action_button = instance.get_node("MarginContainer/HBoxContainer/ButtonContainer/ActionButton")
  assert_eq(action_button.text, "Continue", "Action button should say 'Continue'")
  
  var info_label = instance.get_node("MarginContainer/HBoxContainer/LeftContainer/SlotInfoLabel")
  assert_eq(info_label.text, "Level 5", "Info label should show level")
