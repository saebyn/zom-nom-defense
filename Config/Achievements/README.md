# Achievement System

This directory contains the Achievement Resource Type and achievement definitions for the Zom Nom Defense game.

## AchievementResource

The `AchievementResource` is a custom Godot Resource type that defines individual achievements in the game. It includes:

### Properties

#### Basic Properties
- **id**: Unique identifier for the achievement (String)
- **name**: Display name shown to the player (String)
- **description**: Detailed description of the achievement (String)
- **icon**: Visual icon for the achievement (Texture2D)

#### Unlock Conditions
- **use_multiple_conditions**: Whether to use multiple conditions for complex achievements (bool, default: false)

**For single condition achievements (use_multiple_conditions = false):**
- **unlock_condition_type**: Type of condition to track (ConditionType enum)
- **threshold**: Numerical threshold that must be reached to unlock (int)
- **condition_target**: Optional target for typed conditions, e.g., enemy type name (String)

**For multiple condition achievements (use_multiple_conditions = true):**
- **condition_logic**: How to combine conditions - AND (all must be met) or OR (any must be met) (ConditionLogic enum)
- **conditions**: Array of AchievementCondition objects defining each requirement (Array[AchievementCondition])

#### Display
- **hidden**: Whether the achievement is hidden until unlocked (bool)

#### Rewards
- **reward**: Reward identifier that could unlock tech tree items, buildings, etc. (String)

### Condition Types

The `ConditionType` enum supports the following tracking types:

1. **ENEMIES_DEFEATED_TOTAL**: Track total enemies defeated across all types
2. **ENEMIES_DEFEATED_BY_TYPE**: Track enemies defeated of a specific type (requires `condition_target`)
3. **CLICKS_PERFORMED**: Track total raw clicks performed by the player
4. **HAND_KILLS**: Track total enemies defeated by hand (player clicks)
5. **SCRAP_EARNED**: Track total scrap earned over all time
6. **BUILDINGS_PLACED**: Track total buildings placed
7. **WAVE_COMPLETED**: Track waves completed in a single game
8. **GAME_SCENARIO_REACHED**: Track highest game scenario reached
9. **PLAYER_LEVEL_REACHED**: Track player XP level reached

### Methods

- **is_valid()**: Validates that the achievement resource has all required fields
  - For single conditions: checks id, name, threshold, and type-specific requirements
  - For multiple conditions: validates each condition in the array
- **get_condition_description()**: Returns a human-readable description of the unlock condition(s)
  - For single conditions: returns simple description like "Defeat 10 enemies"
  - For multiple conditions: joins conditions with AND/OR, e.g., "Defeat 50 enemies AND Place 10 buildings"

### Nested Class: AchievementCondition

When using multiple conditions, each condition is represented by an `AchievementCondition` object with:
- **condition_type**: The type of stat to track (ConditionType enum)
- **threshold**: The numerical value that must be reached (int)
- **condition_target**: Optional target for type-specific conditions (String)

## Creating Achievement Resources

### Using the Godot Editor

1. Right-click in the FileSystem panel
2. Select "New Resource..."
3. Choose "AchievementResource"
4. Configure the properties in the Inspector
5. Save the resource as a `.tres` file

### Example: Simple Achievement

```gdscript
# Create a basic achievement for defeating the first enemy
var achievement = AchievementResource.new()
achievement.id = "first_blood"
achievement.name = "First Blood"
achievement.description = "Defeat your first enemy"
achievement.unlock_condition_type = AchievementResource.ConditionType.ENEMIES_DEFEATED_TOTAL
achievement.threshold = 1
achievement.hidden = false
```

### Example: Type-Specific Achievement

```gdscript
# Create an achievement for defeating a specific enemy type
var achievement = AchievementResource.new()
achievement.id = "zombie_slayer"
achievement.name = "Zombie Slayer"
achievement.description = "Defeat 100 Basic_zombie enemies"
achievement.unlock_condition_type = AchievementResource.ConditionType.ENEMIES_DEFEATED_BY_TYPE
achievement.threshold = 100
achievement.condition_target = "Basic_zombie"
achievement.hidden = false
```

### Example: Hidden Achievement with Reward

```gdscript
# Create a hidden achievement that unlocks content
var achievement = AchievementResource.new()
achievement.id = "secret_master"
achievement.name = "Secret Master"
achievement.description = "Discover the secret technique"
achievement.unlock_condition_type = AchievementResource.ConditionType.PLAYER_LEVEL_REACHED
achievement.threshold = 50
achievement.hidden = true
```

### Example: Multiple Conditions with AND Logic

```gdscript
# Create an achievement requiring multiple conditions (all must be met)
var achievement = AchievementResource.new()
achievement.id = "multi_tasker"
achievement.name = "Multi-Tasker"
achievement.description = "Defeat enemies while building defenses"
achievement.use_multiple_conditions = true
achievement.condition_logic = AchievementResource.ConditionLogic.AND

# Add first condition: defeat 50 enemies
var cond1 = AchievementResource.AchievementCondition.new()
cond1.condition_type = AchievementResource.ConditionType.ENEMIES_DEFEATED_TOTAL
cond1.threshold = 50

# Add second condition: place 10 buildings
var cond2 = AchievementResource.AchievementCondition.new()
cond2.condition_type = AchievementResource.ConditionType.BUILDINGS_PLACED
cond2.threshold = 10

achievement.conditions = [cond1, cond2]
# Result: "Defeat 50 enemies AND Place 10 buildings"
```

### Example: Multiple Conditions with OR Logic

```gdscript
# Create an achievement where any condition can be met
var achievement = AchievementResource.new()
achievement.id = "flexible_path"
achievement.name = "Flexible Path"
achievement.description = "Reach success through different means"
achievement.use_multiple_conditions = true
achievement.condition_logic = AchievementResource.ConditionLogic.OR

# First path: earn lots of scrap
var cond1 = AchievementResource.AchievementCondition.new()
cond1.condition_type = AchievementResource.ConditionType.SCRAP_EARNED
cond1.threshold = 1000

# Second path: reach high player level
var cond2 = AchievementResource.AchievementCondition.new()
cond2.condition_type = AchievementResource.ConditionType.PLAYER_LEVEL_REACHED
cond2.threshold = 15

achievement.conditions = [cond1, cond2]
# Result: "Earn 1000 scrap OR Reach player level 15"
```

### Example: Complex Multi-Condition Achievement

```gdscript
# Create a complex achievement with multiple typed conditions
var achievement = AchievementResource.new()
achievement.id = "zombie_master"
achievement.name = "Zombie Master"
achievement.description = "Master all aspects of zombie defense"
achievement.use_multiple_conditions = true
achievement.condition_logic = AchievementResource.ConditionLogic.AND

# Condition 1: Defeat specific enemy type
var cond1 = AchievementResource.AchievementCondition.new()
cond1.condition_type = AchievementResource.ConditionType.ENEMIES_DEFEATED_BY_TYPE
cond1.threshold = 100
cond1.condition_target = "Basic_zombie"

# Condition 2: Place buildings
var cond2 = AchievementResource.AchievementCondition.new()
cond2.condition_type = AchievementResource.ConditionType.BUILDINGS_PLACED
cond2.threshold = 25

# Condition 3: Earn scrap
var cond3 = AchievementResource.AchievementCondition.new()
cond3.condition_type = AchievementResource.ConditionType.SCRAP_EARNED
cond3.threshold = 500

achievement.conditions = [cond1, cond2, cond3]
# Result: "Defeat 100 Basic_zombie enemies AND Place 25 buildings AND Earn 500 scrap"
```

## Integrating with StatsManager and CurrencyManager

The achievement system is integrated with the existing singleton systems:

**StatsManager** tracks:
- `enemies_defeated_total` and `enemies_defeated_by_type`
- `enemies_defeated_by_hand` (for HAND_KILLS)
- `clicks_performed` (for CLICKS_PERFORMED — raw player clicks)
- `buildings_placed_total` and `buildings_placed_by_type`
- `total_scrap_earned`
- `total_xp_earned`

**CurrencyManager** tracks:
- `current_level` (for PLAYER_LEVEL_REACHED)
- Scrap and XP earning events

The **AchievementManager** (implemented in `Utilities/Systems/achievement_manager.gd`) automatically:
- Loads all achievements from this directory
- Connects to StatsManager and CurrencyManager signals
- Tracks progress and unlocks achievements
- Emits signals when achievements unlock or progress updates

## Sample Achievements

This directory includes two sample achievements:

1. **first_blood.tres**: Defeat your first enemy
2. **zombie_slayer.tres**: Defeat 100 Basic_zombie enemies (with reward)

## Using the Achievement System

### Listening for Achievements

Connect to `AchievementManager` signals to respond to achievement events:

```gdscript
func _ready():
    AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
    AchievementManager.achievement_progress_updated.connect(_on_achievement_progress)

func _on_achievement_unlocked(achievement: AchievementResource):
    print("Achievement unlocked: ", achievement.name)
    # Show notification UI, play sound, award rewards

func _on_achievement_progress(achievement: AchievementResource, progress: float):
    print("Progress: ", achievement.name, " - ", progress * 100, "%")
```

### Checking Achievement Status

Query achievement status from anywhere in the code:

```gdscript
# Check if unlocked
if AchievementManager.is_achievement_unlocked("first_blood"):
    print("First Blood unlocked!")

# Get progress (0.0 to 1.0)
var progress = AchievementManager.get_achievement_progress("zombie_slayer")
print("Zombie Slayer: ", progress * 100, "% complete")

# Get all unlocked achievements
var unlocked = AchievementManager.get_unlocked_achievements()
```

### Persistence

`SaveManager` writes `achievements` to `user://saves/save_slot_N.save` on
Victory, Game Over, or abandonment—not on unlock.

## Technical Notes

- The `AchievementResource` uses Godot's `@export` annotations for easy editing in the inspector
- Validation ensures achievements have all required fields before use
- The resource follows the same patterns as `EnemyTypeResource` and `BuildingTypeResource`
- The script is registered as a global class with `class_name AchievementResource`
