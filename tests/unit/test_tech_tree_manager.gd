extends GutTest

## Unit tests for TechTreeManager autoload
## Tests tech tree loading, unlock validation, mutual exclusivity, and branch completion

var _previous_bypass_setting: bool

func before_each():
  # Capture the existing bypass setting so it can be restored after each test
  _previous_bypass_setting = ProjectSettings.get_setting("zom_nom_defense/debug/bypass_tech_requirements", false)
  
  # Reset the TechTreeManager state before each test
  TechTreeManager.reset_tech_tree()
  
  # Reset CurrencyManager to known state
  CurrencyManager.current_scrap = 100
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  
  # Ensure bypass is off by default
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", false)

func after_each():
  # Restore the bypass setting to whatever it was before the test ran
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", _previous_bypass_setting)
  
  # Restore CurrencyManager to clean state
  CurrencyManager.current_scrap = 100
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1

func test_tech_tree_loads_tech_nodes():
  # Assert - verify that tech nodes were loaded from Config/TechTree/
  assert_gt(TechTreeManager.tech_nodes.size(), 0, "Should load at least one tech node")

func test_can_unlock_tech_with_valid_level():
  # Arrange
  CurrencyManager.current_level = 1
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("tur_scrap_shooter")
  
  # Assert
  assert_true(can_unlock, "Should be able to unlock starter tech at level 1")

func test_cannot_unlock_tech_with_insufficient_level():
  # Arrange
  CurrencyManager.current_level = 1
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("clk_shock_click")
  
  # Assert
  assert_false(can_unlock, "Should not be able to unlock tech requiring level 3")

func test_cannot_unlock_tech_without_prerequisites():
  # Arrange
  CurrencyManager.current_level = 3
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("clk_double_tap")
  
  # Assert
  assert_false(can_unlock, "Should not be able to unlock tech without prerequisite")

func test_can_unlock_tech_with_prerequisites():
  # Arrange
  CurrencyManager.current_level = 3
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("clk_double_tap")
  
  # Assert
  assert_true(can_unlock, "Should be able to unlock tech with prerequisite satisfied")

func test_unlock_tech_adds_to_unlocked_list():
  # Arrange
  CurrencyManager.current_level = 1
  
  # Act
  var result = TechTreeManager.unlock_tech("tur_scrap_shooter")
  
  # Assert
  assert_true(result, "Should return true when unlocking")
  assert_true(TechTreeManager.is_tech_unlocked("tur_scrap_shooter"), "Tech should be in unlocked list")

func test_unlock_tech_emits_signal():
  # Arrange
  CurrencyManager.current_level = 1
  watch_signals(TechTreeManager)
  
  # Act
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  
  # Assert
  assert_signal_emitted(TechTreeManager, "tech_unlocked")
  assert_signal_emitted_with_parameters(TechTreeManager, "tech_unlocked", ["tur_scrap_shooter"])

func test_cannot_unlock_already_unlocked_tech():
  # Arrange
  CurrencyManager.current_level = 1
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("tur_scrap_shooter")
  
  # Assert
  assert_false(can_unlock, "Should not be able to unlock already unlocked tech")

func test_mutual_exclusivity_locks_alternative_tech():
  # Arrange
  CurrencyManager.current_level = 3
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  assert_true(TechTreeManager.can_unlock_tech("clk_shock_click"))
  
  # Act
  assert_true(TechTreeManager.unlock_tech("clk_double_tap"))
  
  # Assert
  assert_true(TechTreeManager.is_tech_locked("clk_shock_click"), "Mutually exclusive tech should be locked")

func test_mutual_exclusivity_emits_locked_signal():
  # Arrange
  CurrencyManager.current_level = 3
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  watch_signals(TechTreeManager)
  
  # Act
  TechTreeManager.unlock_tech("clk_double_tap")
  
  # Assert
  assert_signal_emitted(TechTreeManager, "tech_locked")
  assert_signal_emitted_with_parameters(TechTreeManager, "tech_locked", ["clk_shock_click"])

func test_cannot_unlock_permanently_locked_tech():
  # Arrange
  CurrencyManager.current_level = 3
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  TechTreeManager.unlock_tech("clk_double_tap")
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("clk_shock_click")
  
  # Assert
  assert_false(can_unlock, "Should not be able to unlock permanently locked tech")

func test_get_tech_node_returns_valid_resource():
  # Act
  var tech = TechTreeManager.get_tech_node("tur_scrap_shooter")
  
  # Assert
  assert_not_null(tech, "Should return a tech node resource")
  assert_eq(tech.id, "tur_scrap_shooter", "Should return correct tech node")
  assert_eq(tech.display_name, "Scrap Shooter", "Should have correct display name")

func test_get_techs_in_branch_returns_branch_techs():
  # Act
  var offensive_techs = TechTreeManager.get_techs_in_branch("Offensive")
  
  # Assert
  assert_gt(offensive_techs.size(), 0, "Should return at least one offensive tech")
  for tech in offensive_techs:
    assert_eq(tech.branch_name, "Offensive", "All returned techs should be in Offensive branch")

func test_is_branch_completed_returns_false_initially():
  # Act
  var completed = TechTreeManager.is_branch_completed("Offensive")
  
  # Assert
  assert_false(completed, "Branch should not be completed initially")

func test_electric_fence_follows_spike_barricade_in_defensive_branch():
  CurrencyManager.current_level = 3
  assert_true(TechTreeManager.unlock_tech("ob_crates"))
  assert_false(TechTreeManager.can_unlock_tech("ob_electric_fence"),
    "Electric Fence should remain locked until Spike Barricade is researched")
  assert_false(BuildingRegistry.is_building_available("electric_fence"))

  assert_true(TechTreeManager.unlock_tech("ob_spike_barricade"))
  assert_true(TechTreeManager.unlock_tech("ob_electric_fence"),
    "Spike Barricade should be the only tech prerequisite for Electric Fence")
  assert_true(BuildingRegistry.is_building_available("electric_fence"))

func test_researching_multiple_techs_makes_each_building_available():
  assert_false(BuildingRegistry.is_building_available("turret"))
  assert_false(BuildingRegistry.is_building_available("wall"))

  assert_true(TechTreeManager.unlock_tech("tur_scrap_shooter"))
  assert_true(TechTreeManager.unlock_tech("ob_crates"))

  assert_true(BuildingRegistry.is_building_available("turret"))
  assert_true(BuildingRegistry.is_building_available("wall"))

func test_reset_tech_tree_clears_unlocked_techs():
  # Arrange
  CurrencyManager.current_level = 1
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  
  # Act
  TechTreeManager.reset_tech_tree()
  
  # Assert
  assert_false(TechTreeManager.is_tech_unlocked("tur_scrap_shooter"), "Tech should not be unlocked after reset")
  assert_eq(TechTreeManager.unlocked_tech_ids.size(), 0, "Unlocked tech list should be empty")

func test_reset_tech_tree_clears_locked_techs():
  # Arrange
  CurrencyManager.current_level = 3
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  TechTreeManager.unlock_tech("clk_double_tap")
  
  # Act
  TechTreeManager.reset_tech_tree()
  
  # Assert
  assert_false(TechTreeManager.is_tech_locked("clk_shock_click"), "Tech should not be locked after reset")
  assert_eq(TechTreeManager.locked_tech_ids.size(), 0, "Locked tech list should be empty")

## Debug mode tests

func test_debug_mode_bypasses_level_requirement():
  # Arrange - tech requires level 3, player is level 1
  CurrencyManager.current_level = 1
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", true)
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("clk_shock_click")
  
  # Assert
  assert_true(can_unlock, "Debug mode should bypass level requirement")

func test_debug_mode_bypasses_prerequisite_requirement():
  # Arrange - Hydraulic Mouse is not unlocked
  CurrencyManager.current_level = 3
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", true)
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("clk_double_tap")
  
  # Assert
  assert_true(can_unlock, "Debug mode should bypass prerequisite requirement")

func test_debug_mode_bypasses_scrap_cost():
  # Arrange - no scrap, tech has scrap cost
  CurrencyManager.current_scrap = 0
  CurrencyManager.current_level = 1
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", true)
  
  # Act - use a tech that has scrap_cost > 0 if any; otherwise unlock a normal tech
  var can_unlock = TechTreeManager.can_unlock_tech("tur_scrap_shooter")
  
  # Assert
  assert_true(can_unlock, "Debug mode should allow unlock regardless of scrap balance")

func test_debug_mode_does_not_spend_scrap_on_unlock():
  # Arrange
  CurrencyManager.current_scrap = 50
  CurrencyManager.current_level = 1
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", true)
  var scrap_before = CurrencyManager.get_scrap()
  
  # Act
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  
  # Assert
  assert_eq(CurrencyManager.get_scrap(), scrap_before, "Debug mode should not spend scrap on unlock")

func test_debug_mode_still_blocks_already_unlocked_tech():
  # Arrange
  CurrencyManager.current_level = 1
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", true)
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("tur_scrap_shooter")
  
  # Assert
  assert_false(can_unlock, "Debug mode should not allow re-unlocking an already unlocked tech")

func test_debug_mode_still_blocks_permanently_locked_tech():
  # Arrange
  CurrencyManager.current_level = 3
  TechTreeManager.unlock_tech("clk_hydraulic_mouse")
  TechTreeManager.unlock_tech("clk_double_tap")
  ProjectSettings.set_setting("zom_nom_defense/debug/bypass_tech_requirements", true)
  
  # Act
  var can_unlock = TechTreeManager.can_unlock_tech("clk_shock_click")
  
  # Assert
  assert_false(can_unlock, "Debug mode should not bypass permanent mutual-exclusivity lock")

## list_unlocked_techs tests

func test_list_unlocked_techs_returns_empty_initially():
  # Act
  var unlocked = TechTreeManager.list_unlocked_techs()
  
  # Assert
  assert_eq(unlocked.size(), 0, "Should return empty array when no techs are unlocked")

func test_list_unlocked_techs_returns_unlocked_tech_ids():
  # Arrange
  CurrencyManager.current_level = 1
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  
  # Act
  var unlocked = TechTreeManager.list_unlocked_techs()
  
  # Assert
  assert_has(unlocked, "tur_scrap_shooter", "Should include the unlocked tech ID")
  assert_eq(unlocked.size(), 1, "Should return exactly one tech ID")

func test_list_unlocked_techs_returns_duplicate_not_internal_array():
  # Arrange
  CurrencyManager.current_level = 1
  TechTreeManager.unlock_tech("tur_scrap_shooter")
  
  # Act - mutate the returned array
  var unlocked = TechTreeManager.list_unlocked_techs()
  unlocked.clear()
  
  # Assert - internal state should be unchanged; call list_unlocked_techs() again to verify
  var unlocked_again = TechTreeManager.list_unlocked_techs()
  assert_eq(unlocked_again.size(), 1, "Clearing returned array should not affect internal state")
  assert_has(unlocked_again, "tur_scrap_shooter", "Internal state should still contain the unlocked tech")
