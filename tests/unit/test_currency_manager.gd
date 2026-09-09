extends GutTest

## Example unit test for CurrencyManager autoload
## This demonstrates basic GUT testing functionality

func before_each():
  # Set game state to PLAYING so earn_scrap/earn_xp functions work
  # Note: Must be set BEFORE resetting CurrencyManager to ensure signals work correctly
  GameManager.set_game_state(GameManager.GameState.PLAYING)
  
  # Wait a frame to ensure state change is processed
  await get_tree().process_frame
  
  # Reset the CurrencyManager state before each test
  CurrencyManager.current_scrap = 0
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  
  # Verify we're in PLAYING state (sanity check)
  assert_true(GameManager.is_playing(), "PRECONDITION: GameManager must be in PLAYING state")

func after_each():
  # Reset game state after each test
  GameManager.set_game_state(GameManager.GameState.MAIN_MENU)

func test_earn_scrap_increases_total():
  # Arrange
  var initial_scrap = CurrencyManager.current_scrap
  
  # Act
  CurrencyManager.earn_scrap(50)
  
  # Assert
  assert_eq(CurrencyManager.current_scrap, initial_scrap + 50, "Scrap should increase by 50")

func test_spend_scrap_returns_true_when_enough_scrap():
  # Arrange
  CurrencyManager.current_scrap = 100
  
  # Act
  var result = CurrencyManager.spend_scrap(50)
  
  # Assert
  assert_true(result, "Should return true when spending with sufficient scrap")
  assert_eq(CurrencyManager.current_scrap, 50, "Should have 50 scrap remaining")

func test_spend_scrap_returns_false_when_insufficient_scrap():
  # Arrange
  CurrencyManager.current_scrap = 30
  
  # Act
  var result = CurrencyManager.spend_scrap(50)
  
  # Assert
  assert_false(result, "Should return false when spending with insufficient scrap")
  assert_eq(CurrencyManager.current_scrap, 30, "Scrap should remain unchanged")

func test_earn_xp_increases_total():
  # Arrange
  var initial_xp = CurrencyManager.current_xp
  
  # Act
  CurrencyManager.earn_xp(25)
  
  # Assert
  assert_eq(CurrencyManager.current_xp, initial_xp + 25, "XP should increase by 25")

func test_level_up_occurs_at_xp_threshold():
  # Arrange
  CurrencyManager.current_level = 1
  CurrencyManager.current_xp = 0
  
  # Act - Earn exactly enough XP to level up (100 XP for level 1->2)
  CurrencyManager.earn_xp(100)
  
  # Assert
  assert_eq(CurrencyManager.current_level, 2, "Should level up to level 2")
  assert_eq(CurrencyManager.current_xp, 0, "XP should reset to 0 after leveling up")

func test_multiple_level_ups_from_large_xp_gain():
  # Arrange
  CurrencyManager.current_level = 1
  CurrencyManager.current_xp = 0
  
  # Act - Earn enough XP for multiple level ups (100 + 200 = 300 XP for levels 1->2->3)
  CurrencyManager.earn_xp(300)
  
  # Assert
  assert_eq(CurrencyManager.current_level, 3, "Should level up to level 3")
  assert_eq(CurrencyManager.current_xp, 0, "XP should reset to 0 after leveling up")

func test_reset_scrap_sets_to_starting_amount():
  # Arrange
  CurrencyManager.current_scrap = 500
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  CurrencyManager.reset_scrap()
  
  # Assert
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting_scrap value")

func test_convert_remaining_scrap_to_xp_with_valid_scrap():
  # Arrange - use 198 scrap so XP (99) doesn't trigger level up (needs 100)
  CurrencyManager.current_scrap = 198
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  CurrencyManager.scrap_to_xp_conversion_rate = 2.0
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  var result = CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Assert
  assert_eq(result.scrap_converted, 198, "Should convert 198 scrap")
  assert_eq(result.xp_gained, 99, "Should gain 99 XP (198 / 2.0)")
  assert_eq(CurrencyManager.current_xp, 99, "Current XP should be 99")
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting amount")

func test_convert_remaining_scrap_to_xp_with_zero_scrap():
  # Arrange
  CurrencyManager.current_scrap = 0
  CurrencyManager.current_xp = 50
  CurrencyManager.current_level = 1
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  var result = CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Assert
  assert_eq(result.scrap_converted, 0, "Should convert 0 scrap")
  assert_eq(result.xp_gained, 0, "Should gain 0 XP")
  assert_eq(CurrencyManager.current_xp, 50, "Current XP should remain unchanged")
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting amount")

func test_convert_remaining_scrap_to_xp_with_insufficient_scrap_for_conversion():
  # Arrange
  CurrencyManager.current_scrap = 1  # Less than conversion rate
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  CurrencyManager.scrap_to_xp_conversion_rate = 2.0
  var starting_scrap = CurrencyManager.starting_scrap
  
  # Act
  var result = CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Assert
  assert_eq(result.scrap_converted, 1, "Should attempt to convert 1 scrap")
  assert_eq(result.xp_gained, 0, "Should gain 0 XP (1 / 2.0 = 0 when converted to int)")
  assert_eq(CurrencyManager.current_xp, 0, "Current XP should remain 0")
  assert_eq(CurrencyManager.current_scrap, starting_scrap, "Scrap should reset to starting amount")

func test_convert_remaining_scrap_causes_level_up():
  # Arrange
  CurrencyManager.current_scrap = 200
  CurrencyManager.current_xp = 0
  CurrencyManager.current_level = 1
  CurrencyManager.scrap_to_xp_conversion_rate = 2.0
  
  # Act
  CurrencyManager.convert_remaining_scrap_to_xp()
  
  # Assert - 200 scrap = 100 XP, which should level up from 1 to 2
  assert_eq(CurrencyManager.current_level, 2, "Should level up to level 2")
  assert_eq(CurrencyManager.current_xp, 0, "XP should be 0 after leveling up (100 XP used for level up)")

func test_get_xp_for_next_level():
  # Arrange
  CurrencyManager.current_level = 1
  
  # Act
  var xp_needed = CurrencyManager.get_xp_for_next_level()
  
  # Assert
  assert_eq(xp_needed, 100, "Level 1 should need 100 XP to reach level 2")
  
  # Test level 3
  CurrencyManager.current_level = 3
  xp_needed = CurrencyManager.get_xp_for_next_level()
  assert_eq(xp_needed, 300, "Level 3 should need 300 XP to reach level 4")

func test_pulse_display_requests_valid_value():
  watch_signals(CurrencyManager)

  CurrencyManager.pulse_display("LEVEL")

  assert_signal_emitted_with_parameters(CurrencyManager, "display_pulse_requested", ["level", 3.0])

func test_pulse_display_ignores_unknown_value():
  watch_signals(CurrencyManager)

  CurrencyManager.pulse_display("coins")

  assert_signal_not_emitted(CurrencyManager, "display_pulse_requested")

func test_pulse_display_ignores_removed_xp_value():
  watch_signals(CurrencyManager)

  CurrencyManager.pulse_display("xp")

  assert_signal_not_emitted(CurrencyManager, "display_pulse_requested")
