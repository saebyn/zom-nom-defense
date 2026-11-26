# Zom Nom Defense: Click. Aim. Survive. - Game Design Document

> **Domain terminology:** See [`docs/UBIQUITOUS_LANGUAGE.md`](UBIQUITOUS_LANGUAGE.md) for canonical names used in code and documentation.

## Overview

**Zom Nom Defense** is a lo-fi, chaotic, click-powered tower defense game where the player must defend helpless survivors from waves of zombies using scrap-built defenses. Starting with just their mouse, the player clicks zombies to earn "Scrap," which is then spent to build automated turrets, obstacles, and support structures. Progression is tied to both experience (XP) and specific achievements.

### Genre

Tower Defense / Clicker Hybrid

### Target Platform

PC (Steam), with optional Twitch integration for live playthroughs and audience interaction.

---

## Core Gameplay

### Player Actions

1. **Click Zombies** – Deal manual damage to enemies.
2. **Place Obstacles** – Non-damaging walls or barriers to delay enemies.
3. **Place Turrets** – Automated scrap-based defenses that attack zombies.
4. **Place Support Towers** – Enhance nearby turrets (range, fire rate, etc.).

### Defend Survivors

- Survivors do not fight or help.
- Some may attempt to flee short distances but never leave the designated "focus" area.
- Losing all survivors = game over.

### Currency: Scrap

- Earned by defeating zombies.
- Spent to place and upgrade defenses.
- Flavor: Constructed from defeated zombie parts or junk in the environment.

### Progression

- Player starts with only a few defenses.
- Completing specific **achievements** (e.g., "Click 5 times", "Defeat a zombie") unlocks more tech.
- **XP system** levels the player up, enabling access to higher tiers in the tech tree.
- **Progress persists across sessions** via save files.

**Achievement System**:
- **In-Game Achievements**: Track progress per save slot, reset on new game. Used to unlock tech tree nodes.
- **Steam Achievements**: Unlock globally and permanently when first earned, accumulate across all save slots.

**Save System**:
- **Multiple save slots** (minimum 3, like Factorio) allow parallel playthroughs.
- Each save slot maintains independent progression: tech tree choices, in-game achievements, lifetime stats, scenario completion and records, XP, and survivor profiles.
- Victory awards XP from reclaimed and leftover scrap plus the scenario completion bonus, and saves the result. Scrap itself never carries into a new attempt.
- Game Over, Restart, and leaving through the pause menu preserve lifetime stats and achievements, but not XP, in-scenario tech choices, survivor changes, or a scenario clear.
- Main-menu tech choices save immediately. There are no timed saves or mid-scenario resumes.
- Global data (Steam achievements, settings) persists across all saves.
- Players can explore different tech tree paths in different save slots.

### Tech Tree

- Branching structure with **mutually exclusive choices**.
- At key decision points, players choose between competing specializations (e.g., Rapid Fire vs Heavy Damage).
- **Exclusive choices are permanent per save slot once saved** - main-menu choices save immediately; in-scenario choices save on Victory.
- Some unlocks require both a minimum level **and** achievement.
- Advanced tiers may require completing an entire branch before unlocking.
- No unlock tickets or upgrade tokens.
- **Multiple save slots** allow players to explore different tech paths in separate playthroughs.

**Design Philosophy**: Tech tree choices create distinct playstyles and encourage replayability. Players experience meaningful strategic decisions with lasting consequences.

---

## Scenario Structure

- Scenarios are linear but varied in terrain, survivor setup, and zombie wave composition.

### Sample Scenarios

- **Scenario 1:** Defend a person on top of a car.
- **Scenario 2:** Protect two survivors next to a campfire.
- **Scenario 3+:** Scenarios become more ridiculous (e.g., a hammock between two poles, an inflatable pool).

---

## Aesthetic & Tone

- Modern lo-fi 3D graphics with clean UI.
- Silly but strategic tone.
- Names, icons, and audio should reflect light-hearted post-apocalypse vibe.

### Art Style

- **Modern Lo-Fi Aesthetic** - Stylized low-poly 3D with simple, painterly textures
- **Orthographic camera** (45° dimetric projection) providing clear top-down gameplay view
- **Smooth organic forms**, not blocky/cubic (think Firewatch, A Short Hike, not Minecraft)
- **Limited color palette** for visual cohesion
- **Character models**: 500-2000 polygons with hand-painted textures
- **Clear silhouettes** and readable gameplay elements
- **Charming and inviting**, not scary or gross

See `docs/visual_style_guide.md` for comprehensive visual specifications.

### Audio

- Simple click sounds, fun turret SFX, occasional survivor yelps.
- Light zombie groans.
- Comedic or upbeat apocalyptic soundtrack.

---

## Twitch Integration (Optional Feature)

- Viewers vote on special zombie types to spawn in upcoming waves.
- Viewers can name survivors.
- Viewers earn in-stream points and use them to "sabotage" or "aid" (e.g., give bonus Scrap or spawn an elite zombie).

---

## Planned Features

- Multiple enemy types with different behaviors (Fast Scouts, Tanks, Sprinters, Armored, Swarms, Bosses).
- Scrap economy balancing.
- Upgradeable towers (3-5 tiers per tower type with visual progression).
- **Challenge scenarios** with unique win conditions:
  - "Click Only" - No obstacles allowed
  - "No Turrets" - Walls and support only
  - "Speed Run" - Complete scenario in time limit
  - "Limited Budget" - Fixed scrap amount
  - "Horde Mode" - Survive maximum waves
- **Endless mode** with increasing difficulty and leaderboards.
- **Support towers** with buff auras (Range Booster, Fire Rate Booster, Damage Amplifier, Scrap Generator).
- Resource-based data loading (tech tree, achievements, obstacles stored as .tres files).
- Visual and audio polish (particle effects, screen shake, damage numbers, comedic soundtrack).

---

## Development Notes

- Built in Godot 4
- Feature-based folder structure using template + config patterns.
- Resource-based configuration (.tres files) for data-driven design.
- Component-based architecture (Health, Attack, Buff components).
- Autoload singletons: CurrencyManager, StatsManager, AchievementManager, TechTreeManager, BuildingRegistry, GameManager, MyLogger, AudioManager.
- Multiple save slot system with per-slot and global data separation.
- Current implementation: ~25-30% complete (solid technical foundation, missing progression systems and content variety).
- GitHub repo: [https://github.com/saebyn/zom-nom-defense](https://github.com/saebyn/zom-nom-defense)

---

## Title Screen / Steam Branding

**Name:** Zom Nom Defense: Click. Aim. Survive.
**Subtitle:** Lighthearted zombie tower defense with a click-to-kill twist.

---

## Tags

Zombies, Tower Defense, Indie, Clicker, Survival, Strategy, Comedy, Twitch Integration
