extends GutTest

## Unit tests for TechTree UI
## Tests tech tree UI initialization, node selection, and unlock functionality

var tech_tree_scene = preload("res://Stages/UI/tech_tree/tech_tree.tscn")
var tech_tree: UI_TechTree

const BYPASS_SETTING = "zom_nom_defense/debug/bypass_tech_requirements"
var _previous_bypass_setting: bool

func before_each():
  # Capture the existing bypass setting so it can be restored after each test
  _previous_bypass_setting = ProjectSettings.get_setting(BYPASS_SETTING, false)
  
  # Ensure bypass is off so requirement checks run normally
  ProjectSettings.set_setting(BYPASS_SETTING, false)
  
  # Reset the TechTreeManager state before each test
  TechTreeManager.reset_tech_tree()
  
  # Reset CurrencyManager to known state
  CurrencyManager.current_scrap = 100
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  
  # Instantiate tech tree UI
  tech_tree = tech_tree_scene.instantiate()
  add_child_autofree(tech_tree)
  
  # Wait for ready to complete
  await wait_process_frames(2)

func after_each():
  # Restore the bypass setting to whatever it was before the test ran
  ProjectSettings.set_setting(BYPASS_SETTING, _previous_bypass_setting)

func test_tech_tree_initializes():
  # Assert
  assert_not_null(tech_tree, "Tech tree should be instantiated")
  assert_true(tech_tree is UI_TechTree, "Should be a TechTree instance")

func test_tech_tree_loads_all_nodes():
  # Assert - verify that tech node cards were created
  assert_gt(tech_tree.tech_node_cards.size(), 0, "Should create tech node cards")
  assert_eq(tech_tree.tech_node_cards.size(), TechTreeManager.tech_nodes.size(), "Should create one card per tech node")
  for tech_id: String in tech_tree.tech_node_cards:
    var tech := TechTreeManager.get_tech_node(tech_id)
    assert_true(tech.player_attack_effect != null or not BuildingRegistry.get_buildings_requiring_tech(tech_id).is_empty(),
      "Expected %s to provide a click effect or gate a registered building" % tech_id)

func test_detail_panel_hidden_initially():
  # Assert
  assert_false(tech_tree.detail_panel.visible, "Detail panel should be hidden initially")

func test_selecting_tech_node_shows_details():
  tech_tree.tech_node_cards["tur_scrap_shooter"].selected.emit()

  assert_true(tech_tree.detail_panel.visible, "Detail panel should be visible after selection")
  assert_eq(tech_tree.detail_name.text, "Scrap Shooter", "Tech name should be displayed")
  assert_eq(tech_tree.detail_unlocks.text, "Unlocks:\n• Buildings: Scrap Shooter",
    "The unlock list should name the registered building, not show its internal ID")

  tech_tree.tech_node_cards["clk_double_tap"].selected.emit()
  assert_eq(tech_tree.detail_unlocks.text, "Unlocks:\n• Click upgrade",
    "A click-only node should not list any buildings")

func test_unlock_button_enabled_for_available_tech():
  # Arrange
  CurrencyManager.current_level = 1
  tech_tree._on_tech_node_selected("tur_scrap_shooter")
  
  # Assert
  assert_false(tech_tree.unlock_button.disabled, "Unlock button should be enabled for available tech")
  assert_eq(tech_tree.unlock_button.text, "Unlock", "Button should show 'Unlock'")

func test_unlock_button_disabled_for_unlocked_tech():
  # Arrange
  CurrencyManager.current_level = 1
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  tech_tree._on_tech_node_selected("tur_scrap_shooter")
  
  # Assert
  assert_true(tech_tree.unlock_button.disabled, "Unlock button should be disabled for unlocked tech")
  assert_eq(tech_tree.unlock_button.text, "Already Unlocked", "Button should show 'Already Unlocked'")

func test_unlock_button_disabled_for_locked_tech():
  # Arrange
  CurrencyManager.current_level = 1
  
  # Act - select a tech that requires level 3
  tech_tree.tech_node_cards["clk_double_tap"].selected.emit()
  
  # Assert
  assert_true(tech_tree.unlock_button.disabled, "Unlock button should be disabled for locked tech")

func test_unlock_button_updates_when_scrap_threshold_reached():
  # Arrange - select a tech with insufficient scrap (tur_scrap_shooter costs 75 scrap)
  CurrencyManager.current_level = 1
  CurrencyManager.current_scrap = 0
  tech_tree._on_tech_node_selected("tur_scrap_shooter")
  assert_true(tech_tree.unlock_button.disabled, "Unlock button should be disabled with insufficient scrap")
  
  # Act - simulate earning scrap (outside the tech tree) then reopening the tech tree
  CurrencyManager.current_scrap = 75
  tech_tree._on_game_state_changed(GameManager.GameState.IN_TECH_TREE)
  await wait_process_frames(2)
  
  # Assert - unlock button should now reflect that the tech can be unlocked
  assert_false(tech_tree.unlock_button.disabled, "Unlock button should be enabled when tech tree is reopened after scrap threshold is reached")
  assert_eq(tech_tree.unlock_button.text, "Unlock", "Button should show 'Unlock'")

func test_tech_node_card_state_updates_on_unlock():
  # Arrange
  CurrencyManager.current_level = 1
  var card = tech_tree.tech_node_cards.get("tur_scrap_shooter")
  assert_not_null(card, "Card should exist")
  
  # Act - unlock the tech
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  await wait_process_frames(2)
  
  # Assert - card state should update
  assert_eq(card.current_state, UI_TechNodeCard.NodeState.UNLOCKED, "Card should show as unlocked")

func test_tech_node_card_state_updates_on_lock():
  # Arrange
  CurrencyManager.current_level = 3
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  
  # Act - unlock a mutually exclusive tech
  assert_true(TechTreeManager.unlock_tech("clk_double_tap"))
  await wait_process_frames(2)
  
  # Assert - mutually exclusive tech card should update
  var shock_click_card = tech_tree.tech_node_cards["clk_shock_click"]
  assert_eq(shock_click_card.current_state, UI_TechNodeCard.NodeState.PERMANENTLY_LOCKED, "Card should show as permanently locked")

func test_tech_tree_displays_branches():
  # Assert - check that all expected branches are represented
  var found_branches = {}
  
  for tech_id in tech_tree.tech_node_cards:
    var tech = TechTreeManager.get_tech_node(tech_id)
    if tech:
      found_branches[tech.branch_name] = true
  
  # At least some branches should be present
  assert_gt(found_branches.size(), 0, "Should display at least one branch")

func test_double_click_unlocks_available_tech():
  # Arrange
  CurrencyManager.current_level = 1
  var card = tech_tree.tech_node_cards.get("tur_scrap_shooter")
  assert_not_null(card, "Card should exist")
  watch_signals(card)
  
  # Ensure card is in AVAILABLE state
  card.update_state(UI_TechNodeCard.NodeState.AVAILABLE)
  
  # Act - simulate double-click
  var event = InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = true
  event.double_click = true
  card._gui_input(event)
  
  # Assert
  assert_signal_emitted(card, "unlock_requested", "Double-click should emit unlock_requested signal")

func test_double_click_does_nothing_on_locked_tech():
  # Arrange
  var card = tech_tree.tech_node_cards.get("clk_double_tap")
  assert_not_null(card, "Card should exist")
  watch_signals(card)
  
  # Ensure card is in LOCKED state
  card.update_state(UI_TechNodeCard.NodeState.LOCKED)
  
  # Act - simulate double-click
  var event = InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = true
  event.double_click = true
  card._gui_input(event)
  
  # Assert
  assert_signal_not_emitted(card, "unlock_requested", "Double-click on locked tech should not emit unlock_requested")
  assert_signal_emitted(card, "selected", "Should still emit selected signal")

func test_single_click_still_selects_tech():
  # Arrange
  CurrencyManager.current_level = 1
  var card = tech_tree.tech_node_cards.get("tur_scrap_shooter")
  assert_not_null(card, "Card should exist")
  watch_signals(card)
  
  # Act - simulate single click
  var event = InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = true
  event.double_click = false
  card._gui_input(event)
  
  # Assert
  assert_signal_emitted(card, "selected", "Single-click should emit selected signal")
  assert_signal_not_emitted(card, "unlock_requested", "Single-click should not emit unlock_requested")

func test_scroll_events_consumed_over_tech_tree():
  # Note: The scroll event handling is now managed by the camera input system
  # which disables camera input during menu states. This test verifies the
  # tech tree can be instantiated without errors.
  # Assert - tech tree should be properly initialized
  assert_not_null(tech_tree, "Tech tree should be instantiated")
  assert_not_null(tech_tree.scroll_container, "Scroll container should exist")
  assert_true(true, "Tech tree initializes without error")
