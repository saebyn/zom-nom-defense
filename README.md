<div align="center">
  <img src="Assets/Icons/icon.svg" alt="Zom Nom Defense Icon" width="128" height="128">
  
  # Zom Nom Defense: Click. Aim. Survive.
  
  <a href="https://saebyn.itch.io/zom-nom-defense">download at Itch.io</a>
</div>

A lighthearted zombie tower defense game with a click-to-kill twist, built with Godot 4.

> 🧟‍♂️ Defend helpless survivors from waves of zombies using nothing but your mouse and some scrap-built defenses. Click zombies for scrap, build automated turrets, and make permanent tech tree choices that shape your playstyle.

---

## 🎮 What Is This?

**Zom Nom Defense** is a lo-fi, chaotic tower defense/clicker hybrid where:
- You **click zombies** to deal manual damage and earn "scrap"
- You spend scrap to **place obstacles and turrets** to automate defense
- You **defend absurd scenarios** (person on a car, survivor in a hammock, inflatable pool party)
- You **earn XP** to meet Player Level requirements for new buildings and click upgrades
- You make **permanent strategic choices** in a branching tech tree (choose Double Tap or Shock Click)

**Genre**: Tower Defense / Clicker Hybrid  
**Platform**: PC (Steam planned)  
**Tone**: Silly but strategic - light-hearted post-apocalypse chaos

---

## ⚠️ Work in Progress

This is a **part-time passion project**. Core systems are functional, but many features and content are still in development.

See the [open issues](https://github.com/saebyn/zom-nom-defense/issues?q=is%3Aissue+is%3Aopen) and [project boards](https://github.com/saebyn/zom-nom-defense/projects) for the current roadmap, known bugs, and planned features.

---

## 📺 Watch Development Live!

This game is being developed **live on stream**!

**🔴 Twitch**: [twitch.tv/saebyn](https://twitch.tv/saebyn)  
**📅 Schedule**: Sunday mornings  
**🎥 VODs**: [@saebynVODs on YouTube](https://www.youtube.com/@saebynVODs)

Come hang out, watch the chaos unfold, and see how the sausage gets made! 🧟‍♂️✨

---

## 🚀 Getting Started

### Prerequisites

- [Godot Engine 4.6](https://godotengine.org/download) or later

### Running the Game

1. Clone this repository with submodules:
   ```bash
   git clone --recurse-submodules <repository-url>
   ```
   Or if already cloned:
   ```bash
   git submodule update --init --recursive
   ```
2. Open the project in Godot by importing the `project.godot` file
3. Press F5 or click the "Play" button to run the game

Controls are fully rebindable in-game via the Settings menu.

### Running Tests

This project uses [GUT (Godot Unit Testing)](https://github.com/bitwes/Gut) for automated testing.

```bash
./run_tests.sh
```

See [tests/README.md](tests/README.md) for more details.

---

## 📚 Documentation

Project documentation and authoring guides:

- **[Game Design Document](docs/zom_nom_defense_gdd.md)** - Full game vision
- **[Ubiquitous Language](docs/UBIQUITOUS_LANGUAGE.md)** - Canonical domain terminology for code and docs
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture, camera boundaries, spawn areas
- **[Class Hierarchy](docs/CLASS_HIERARCHY.md)** - Naming conventions and complete class reference
- **[Tech Tree Editor](addons/tech_tree_editor/README.md)** - How to author and validate tech nodes in Godot
- **[Visual Style Guide](docs/visual_style_guide.md)** - Art direction, color palette, and UI theme
- **[Logging](docs/LOGGING.md)** - `MyLogger` API reference
- **[Adding Settings](docs/adding_settings.md)** - How-to guide for new settings
- **[Links](docs/LINKS.md)** - Helpful resources, tools, and reference links collected during development

---

## 🤝 Contributing & Feedback

Feedback and contributions are welcome! The best places to start:

- 🐛 **[Open Issues](https://github.com/saebyn/zom-nom-defense/issues?q=is%3Aissue+is%3Aopen)** — bug reports, feature requests, and help-wanted items
- 🗺️ **[Project Boards](https://github.com/saebyn/zom-nom-defense/projects)** — roadmap and current development priorities
- 💬 Drop by the [Twitch stream](https://twitch.tv/saebyn) on Sunday mornings to chat live

When filing a bug, please include reproduction steps. Balance feedback and design suggestions are also very welcome!

---

## 📜 License

This project is licensed under the GNU Affero General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

## 🎮 Why "Zom Nom Defense"?

Because zombies go "nom nom nom" and puns are mandatory in lighthearted apocalypse games. 🧟‍♂️🍔

**Tagline**: Click. Aim. Survive.

---

**Built with** [Godot 4](https://godotengine.org/) | **Repo**: [github.com/saebyn/zom-nom-defense](https://github.com/saebyn/zom-nom-defense)
