# Agent Instructions for Zom Nom Defense

Repository guidance for coding agents working on Zom Nom Defense.

## Project Overview

This is a **3D tower defense game** built with **Godot 4**. The project uses a feature-based folder structure with clear separation of concerns and follows a Template + Config pattern for game entities.

### Key Project Details
- **Engine**: Godot 4
- **Project Type**: 3D Tower Defense Game
- **Main Scene**: `Stages/Game/main/main.tscn`
- **Total Scenes**: 17 scenes
- **Total Scripts**: 12 scripts
- **Architecture**: Template + Config pattern for entities

## Critical Setup Requirements

### ⚠️ CRITICAL: Asset Import Timing
**NEVER cancel the initial asset import process!** The first-time asset import takes **15+ minutes minimum**. Cancelling this process will break 3D model rendering and require starting over.

### Godot 4.7 Installation

1. **Download Godot 4.7.2 stable** to match CI:
   ```bash
   wget https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
   unzip Godot_v4.7.2-stable_linux.x86_64.zip
   chmod +x Godot_v4.7.2-stable_linux.x86_64
   mv Godot_v4.7.2-stable_linux.x86_64 ./godot
   ```

2. **Verify Installation**:
   ```bash
   ./godot --version
   # The official build reports 4.7.2.stable.official followed by a commit hash.
   ```

### Project Setup

1. **Initialize Submodules** (⚠️ REQUIRED):
   ```bash
   git submodule update --init --recursive
   ```
   - This downloads external dependencies like the GUT testing framework
   - Always run this after cloning the repository

2. **Initial Asset Import** (⚠️ CRITICAL - DO NOT CANCEL):
   ```bash
   # This takes 15+ minutes minimum - be patient!
   ./godot --headless --import --path .
   # On a fresh checkout, scan again so Dialogic indexes characters and timelines.
   ./godot --headless --import --path .
   ```
   - Wait for complete import before proceeding
   - Script class registration happens during this process

2. **Quick Validation**:
   ```bash
   # Test headless execution (should exit cleanly)
   ./godot --headless --path . "res://Stages/Game/main/main.tscn"
   ```

## Project Structure

### Directory Organization
```
├── Assets/               # Asset files (models, icons)
│   ├── Icons/            # UI icons (PNG or SVG files)
│   ├── Textures/         # Textures (PNG, JPG files)
│   ├── Sounds/           # Audio files (WAV, OGG files)
│   ├── Animations/       # Animation files (if any)
│   ├── Shaders/          # Shader files (if any)
│   ├── Materials/        # Material files (if any)
│   ├── Fonts/            # Font files (if any)
│   └── Models/           # 3D models (*.blend files, etc)
├── Common/               # Shared components and systems
│   ├── Components/       # Reusable components (attack, health)
│   ├── Effects/          # Visual/audio effects (shake_effect)
│   ├── Systems/          # Game systems (spawner)
│   └── UI/               # Common UI components (health_display)
├── Config/               # Configuration files
│   └── Environments/     # Environment configurations
├── Entities/             # Game entities organized by type
│   ├── Enemies/          # Enemy templates and configurations
│   ├── Buildings/        # Building templates and configurations
│   └── Survivors/         # Survivor templates and configurations
├── external/             # External dependencies (git submodules)
│   ├── .gdignore         # Prevents Godot from importing externals
│   └── Gut/              # GUT testing framework (submodule)
├── Localization/         # Internationalization files
├── Stages/               # Game stages/scenes
│   ├── Game/             # Main game scenes
│   └── UI/               # UI scenes
├── tests/                # Unit and integration tests
│   ├── unit/             # Unit tests
│   └── integration/      # Integration tests
└── Utilities/            # Utility scripts and tools
```

### External Dependencies

This project uses git submodules for external dependencies to keep the repository size small:

- **Location**: `external/` directory
- **Godot Ignore**: `external/.gdignore` prevents Godot from importing submodule files
- **Addon Access**: Symlinks in `addons/` point to `external/*/addons/*`
- **Example**: `addons/gut` → `../external/Gut/addons/gut`

**When adding new addons**:
1. Add as submodule: `git submodule add <repo-url> external/<addon-name>`
2. Checkout specific version if needed
3. Create symlink: `ln -s ../external/<addon-name>/addons/<name> addons/<name>`
4. Commit the submodule and symlink (not the addon files directly)

### Key Files
- **Main Scene**: `Stages/Game/main/main.tscn` - Primary game scene
- **Project File**: `project.godot` - Godot project configuration
- **Enemy Template**: `Entities/Enemies/Templates/base_enemy/enemy.tscn`
- **UI Scene**: `Stages/UI/main_ui/ui.tscn`

## Domain Language

All code identifiers, comments, documentation, and UI text must use the canonical terms defined in [`docs/UBIQUITOUS_LANGUAGE.md`](docs/UBIQUITOUS_LANGUAGE.md). Consult that document before introducing or reusing any domain term. Key examples: use **Survivor** (not "target"), **Scenario** (not "level"), **Building** (not "obstacle" generically), **Player Level** (not bare "level") for the progression rank.

## Development Guidelines

### Coding Standards
- Follow Godot GDScript style guide
- Always use 2 spaces for indentation
- Comment complex logic
- Use meaningful variable and function names

### Template + Config Pattern
The project uses a Template + Config architecture:
- **Templates**: Base entity scenes in `Entities/*/Templates/`
- **Configs**: Configuration resources in `Config/`
- **Components**: Reusable components in `Common/Components/`

### Autoloaded Systems
The project uses several autoloaded singletons for global state management:
- **MyLogger**: Comprehensive logging with scope-based filtering (`Utilities/Systems/logger.gd`)
- **CurrencyManager**: Player currency tracking and transactions (`Utilities/Systems/currency_manager.gd`)
- **GameManager**: Game state transitions and high-level coordination (`Utilities/Systems/game_manager.gd`)

Access these systems from anywhere in the codebase:
```gdscript
MyLogger.info("System", "Message")
CurrencyManager.earn_scrap(10)
GameManager.set_game_state(GameManager.GameState.IN_GAME_MENU)
```

### GameManager Details

The `GameManager` singleton manages game states and transitions. It defines an enum for game states and emits signals on state changes. See the `game_manager.gd` autoload script for implementation details.

### Script Class Registration
- Scripts use proper class_name declarations
- Registration happens during asset import
- Restart Godot if class recognition issues occur

### Asset Management
- **Large Assets**: Excluded from git (*.blend, *.blend1)
- **Import Files**: Keep .import files for proper asset handling
- **3D Models**: Require full asset import for proper rendering

## Troubleshooting

### Common Issues and Solutions

1. **"Script class not found" errors**:
   - Ensure complete asset import finished
   - Restart Godot editor
   - Check class_name declarations in scripts

2. **3D models not rendering**:
   - Verify asset import completed (15+ minutes)
   - Check suzanne.blend exists in Assets/Models/
   - Ensure .import files are present

3. **Performance Issues**:
   - Asset import: 15+ minutes (normal)
   - Game launch: 2-3 seconds (normal)
   - Scene loading: < 1 second (normal)

4. **Autoload System Issues**:
   - If MyLogger, CurrencyManager, or GameManager not found: Check project.godot autoload section
   - Verify singleton scripts are properly accessible with their class names
   - Restart Godot if autoload changes don't take effect

### ⚠️ Scene/Resource UID Guidance

Godot 4 scene files (`.tscn`) and resource files (`.tres`) contain `uid="uid://..."` values in their `[ext_resource]` headers. These UIDs are Godot's internal resource identifiers stored in the project's UID registry (`.godot/uid_cache.bin`) — they are **not** related to any `.uid` sidecar files on disk.
- **Do not modify or remove** the `uid="uid://..."` values in `.tscn` and `.tres` files
- These UIDs are automatically generated and managed by Godot during asset import and scene/resource creation
- When you create new scenes or resources, Godot will assign new UIDs to them during the import process, so don't worry about manually managing or creating UIDs for your assets

### Build and Test Commands

1. **Asset Import Validation**:
   ```bash
   # Check for import completion
   ls -la .godot/imported/
   ```

2. **Headless Testing**:
   ```bash
   # Test scene loading without GUI
   ./godot --headless --path . "res://Stages/Game/main/main.tscn"
   ```

3. **Error Checking**:
   ```bash
   # Run with debug output
   ./godot --path . --verbose "res://Stages/Game/main/main.tscn"
   ```

## Important Reminders

1. **Asset Import**: Always allow 15+ minutes for initial import
2. **Large Files**: Excluded from git via .gitignore
3. **Manual Testing**: Required for all changes
4. **Class Registration**: Happens during asset import
5. **3D Models**: Require complete import for rendering

This project requires patience during setup but provides a solid foundation for 3D tower defense development with Godot 4.
