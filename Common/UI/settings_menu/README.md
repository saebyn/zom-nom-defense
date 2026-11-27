# Settings Menu

A comprehensive settings UI system for Godot 4 tower defense game.

## Overview

This settings menu provides a complete interface for adjusting video, audio, and input settings. It's accessible from both the main menu and pause menu, with automatic persistence of all settings.

## Components

### settings_menu.tscn / settings_menu.gd
Main settings UI with three tabs:
- **Video**: Resolution, fullscreen, V-Sync
- **Audio**: Master, Music, SFX volume sliders
- **Keybinds**: Rebindable input actions

### keybind_button.tscn / keybind_button.gd
Reusable component for displaying and rebinding input actions.

## Usage

### From Code

The settings menu is instantiated by parent scenes (main menu, pause menu):

```gdscript
const SettingsMenuScene = preload("res://Common/UI/settings_menu/settings_menu.tscn")

var settings_menu: SettingsMenu = null

func _ready():
    settings_menu = SettingsMenuScene.instantiate()
    add_child(settings_menu)
    settings_menu.closed.connect(_on_settings_closed)

func show_settings():
    settings_menu.show_menu()
```

### For Players

1. Click Settings button from main menu or pause menu
2. Adjust settings in the tabbed interface
3. Click Apply to save changes or Cancel to discard

## Features

- Modal overlay with semi-transparent background
- Real-time feedback on volume changes
- Apply/Cancel functionality
- Automatic settings persistence via SettingsManager
- Process mode 3 (works during pause)

## Integration

This component requires:
- SettingsManager singleton (autoloaded)
- MyLogger system (for logging)
- Godot (see the [project prerequisites](../../../README.md#prerequisites))

## Documentation

See the `/docs` folder for comprehensive documentation:
- `settings_ui_implementation.md` - Complete implementation guide
- `settings_ui_visual_guide.md` - Visual reference with diagrams
- `settings_usage_examples.md` - Code examples
- `SETTINGS_QUICK_REFERENCE.md` - Quick reference card
