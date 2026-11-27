# Scenario Environment System

This document explains how to use the environment system for scenarios in Zom Nom Defense.

## Overview

Each scenario can have its own custom visual environment (lighting, fog, colors) that automatically applies when the scenario loads. This is managed through the `Stage_Scenario` base class and Godot's `WorldEnvironment` node.

## How It Works

1. **WorldEnvironment in Main Scene**: The `main.tscn` has a single `WorldEnvironment` node that controls the scene's visual environment
2. **Environment Resources**: Pre-configured `Environment` resources are stored in `Config/Environments/`
3. **Scenario Export Variable**: Each scenario can optionally reference an environment resource
4. **Automatic Application**: When a scenario loads, it automatically applies its environment to the main `WorldEnvironment`

## Available Environment Presets

### `desert.tres`
- **Used by**: Car Defense (`scenario_1.tscn`)
- **Features**: Warm procedural sky, pale horizon, and sandy ground colors
- **Atmosphere**: Dry and sunlit

### `daytime_bright.tres`
- **Used by**: Test Scenario (`scenario_test.tscn`)
- **Features**: Clear blue procedural sky, green ground colors, and no fog
- **Atmosphere**: Upbeat, visible, clear

### `nighttime_campfire.tres`
- **Used by**: Campfire Survivors (`scenario_2.tscn`)
- **Features**:
  - Dim procedural sky with a warm horizon
  - Sky-sourced ambient lighting
  - Glow enabled for fire effects
- **Atmosphere**: Tense, intimate, dramatic
- **Best with**: `OmniLight3D` for campfire, `DirectionalLight3D` for moonlight

### `golden_hour_forest.tres`
- **Use Case**: Late afternoon forest scenarios (not assigned to a current Scenario)
- **Features**:
  - Warm golden/orange tones
  - Moderate glow for sun rays
  - Light atmospheric fog
- **Atmosphere**: Peaceful, warm, natural
- **Best with**: `DirectionalLight3D` angled low for sunset effect

### `daytime_pool_party.tres`
- **Used by**: Pool Party (`scenario_pool_party.tscn`, ID `scenario_4`)
- **Features**:
  - Solid light-blue background
  - Increased ambient light energy and exposure
  - Subtle glow enabled for bright highlights
- **Atmosphere**: Fun, energetic, bright

## Using in Your Scenario

### Method 1: In Godot Editor (Recommended)

1. Open your scenario scene (e.g., `scenario_2.tscn`)
2. Select the root node (inherits from `Stage_Scenario`)
3. In the Inspector, find **Scenario Settings** category
4. Set **Scenario Environment** property:
   - Click the dropdown
   - Choose "Load"
   - Navigate to `Config/Environments/`
   - Select the appropriate `.tres` file

### Method 2: In GDScript

```gdscript
# scenario_2.gd
extends Stage_Scenario

# This is set automatically if configured in the scene,
# but you can also set it programmatically
func _init():
  # Load the environment resource
  scenario_environment = load("res://Config/Environments/nighttime_campfire.tres")
```

### Method 3: No Environment (Use Default)

Simply leave `scenario_environment` as `null` and the scenario will use whatever environment is already set in `main.tscn`.

## Creating Custom Environments

1. **In Godot Editor**:
   - Right-click in `Config/Environments/`
   - New Resource → Environment
   - Configure settings in Inspector
   - Save as `.tres` file

2. **Key Properties to Configure**:
   - **Background Mode**: Usually `Color` (1)
   - **Background Color**: Sky/horizon color
   - **Ambient Light Source**: `Color` (1) for consistent lighting
   - **Ambient Light Color**: Base color of ambient light
   - **Ambient Light Energy**: Brightness (0.0-2.0)
   - **Tonemap Mode**: Affects overall brightness/contrast
   - **Tonemap Exposure**: Overall scene brightness
   - **Glow**: For bloom effects (fires, bright lights)
   - **Fog**: For atmospheric depth

## Important Considerations

### WorldEnvironment Singleton Rule
- **Only ONE** `WorldEnvironment` can be active per scene tree
- The system assumes `WorldEnvironment` is at `Main/WorldEnvironment`
- If the path changes, update `_apply_environment()` in `Stage_Scenario`

### Environment vs. Lighting
- `Environment` controls **ambient/global** lighting and atmosphere
- `DirectionalLight3D` / `OmniLight3D` nodes provide **direct** lighting
- **Both are needed** for complete scene lighting:
  ```
  scenario_2.tscn
  ├── Environment: nighttime_campfire.tres (dark ambient)
  ├── OmniLight3D (campfire - orange, bright)
  └── DirectionalLight3D (moonlight - blue, dim)
  ```

### Performance
- Changing environments is very fast (just swaps the resource)
- Glow/fog have small performance costs
- Effects such as SSAO, SSR, and SDFGI have higher costs and depend on renderer support.

## Testing Your Environment

Create a simple test scene:

```gdscript
# test_environment.tscn
[Root] Node3D
├── WorldEnvironment (with your environment)
├── Camera3D
├── DirectionalLight3D
└── CSGBox3D (test geometry)
```

This lets you iterate on environment settings without loading the full game.

## Troubleshooting

### "No WorldEnvironment found" Warning
- Check that `main.tscn` has a `WorldEnvironment` node
- Verify the node path is `Main/WorldEnvironment`
- Check console logs for the exact warning

### Environment Not Applying
- Verify `scenario_environment` is set in the Inspector
- Check that the `.tres` file loads correctly (no broken reference)
- Look for errors in the console during scenario load

### Environment Too Dark/Bright
- Adjust `ambient_light_energy` (0.0-2.0)
- Modify `tonemap_exposure` (0.5-1.5)
- Add/adjust `DirectionalLight3D` for additional light

### Colors Don't Match Theme
- Check `ambient_light_color` matches your desired tone
- Verify `background_color` complements the scene
- Consider adding complementary lights (warm + cool balance)

## Example: Scenario 2 Setup

```gdscript
# scenario_2.tscn structure
Scenario2 (Stage_Scenario)
  scenario_environment = nighttime_campfire.tres
  survivor_count = 2
  
├── EnemySpawner
│   ├── NorthSpawnArea
│   ├── EastSpawnArea
│   └── SouthSpawnArea
├── Campfire (Node3D)
│   ├── CampfireModel (MeshInstance3D)
│   ├── OmniLight3D
│   │   ├── light_color = Color(1.0, 0.6, 0.2)
│   │   ├── light_energy = 2.0
│   │   └── omni_range = 15.0
│   └── GPUParticles3D (fire effect)
├── DirectionalLight3D (Moonlight)
│   ├── light_color = Color(0.7, 0.8, 1.0)
│   ├── light_energy = 0.2
│   └── rotation_degrees = Vector3(-120, -45, 0)
└── Survivors (around campfire)
```

This creates the complete nighttime campfire atmosphere!
