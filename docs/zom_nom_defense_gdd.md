# Zom Nom Defense: Click. Aim. Survive. - Game Design Document

> **Domain terminology:** See [`docs/UBIQUITOUS_LANGUAGE.md`](UBIQUITOUS_LANGUAGE.md) for canonical names used in code and documentation.
>
> **Implementation status:** Features marked **Not implemented**, and gaps noted under **Partially implemented**, are ideas under consideration, not commitments.

## Overview

**Zom Nom Defense** is a lo-fi, chaotic, click-powered tower defense game where the player must defend helpless survivors from waves of zombies using scrap-built defenses. Starting with just their mouse, the player clicks zombies to deal damage and earns Scrap by defeating them. Scrap pays for automated turrets, obstacles, and support buildings.

### Genre

Tower Defense / Clicker Hybrid

### Target Platform

PC.

**Steam integration (including Steam achievements)** — **Not implemented**. Steam is a potential distribution platform. The idea is for each Steam achievement to unlock globally and permanently the first time it is earned in any save slot.

---

## Core Gameplay

### Player Actions

1. **Click Zombies** – Deal manual damage to enemies.
2. **Place Obstacles** – Non-damaging walls or barriers to delay enemies.
3. **Place Turrets** – Automated scrap-based defenses that attack zombies.
   - **In-place turret upgrades** — **Not implemented**. The tech tree unlocks new buildings but does not upgrade existing placements. The idea is 3–5 tiers per turret type, each with a distinct look.
4. **Place Support Buildings** – Boost the range, fire rate, or damage of nearby turrets.
   - **Scrap Generator** — **Not implemented**. A proposed support building that would generate Scrap.

### Defend Survivors

- Survivors do not fight or help.
- Some may attempt to flee short distances but never leave the designated "focus" area.
- Losing all survivors = game over.

### Currency: Scrap

- Earned by defeating zombies.
- Spent to place buildings and unlock tech with a Scrap cost.
- Flavor: Constructed from defeated zombie parts or junk in the environment.
- Balancing the existing Scrap economy is an ongoing design goal.

### Progression

- Player starts with only a few defenses.
- Earning **XP** raises Player Level, which can grant access to higher tiers in the tech tree.
- **In-game achievements** track progress per save slot and reset when starting a new game in that slot.

**Save System**:
- **Ten save slots** allow parallel playthroughs, including different tech tree paths.
- Each save slot maintains independent progression: tech tree choices, in-game achievements, lifetime stats, scenario completion and records, XP, and survivor profiles.
- Victory awards XP from reclaimed and leftover scrap plus the scenario completion bonus, and saves the result. Scrap itself never carries into a new attempt.
- Game Over, Restart, and leaving through the pause menu preserve lifetime stats and achievements, but not XP, in-scenario tech choices, survivor changes, or a scenario clear.
- Main-menu tech choices save immediately. There are no timed saves or mid-scenario resumes.
- Settings are shared across all save slots.

### Tech Tree

- Branching structure with **mutually exclusive choices**.
- At key decision points, players choose between competing specializations (e.g., Double Tap vs Shock Click).
- **Exclusive choices are permanent per save slot once saved** - main-menu choices save immediately; in-scenario choices save on Victory.
- Tech unlocks can require a minimum Player Level, a Scrap cost, or prerequisite tech nodes.
- **Whole-branch prerequisites** — **Partially implemented**. The code supports requiring an entire branch for an advanced unlock, but no configured tech node uses it.
- **Achievement-gated tech** — **Not implemented**. Achievements are tracked separately from tech unlocks. One idea is to gate tech behind achievements such as "Click 5 times" or "Defeat a zombie."
- No unlock tickets or upgrade tokens.

**Design Philosophy**: Tech tree choices create distinct playstyles and encourage replayability. Players experience meaningful strategic decisions with lasting consequences.

---

## Scenario Structure

Campaign scenarios unlock in order and vary in terrain, survivor setup, and zombie wave composition. Each uses a fixed set of waves.
The design leans into increasingly silly survivor setups.

### Campaign Scenarios

1. **Car Defense:** Defend a person on top of a car.
2. **Campfire Survivors:** Protect two survivors next to a campfire.
3. **Pool Party:** Defend survivors in an inflatable pool.

### Enemy Variety

**Partially implemented**. Campfire Survivors includes a Boss. Scout, Tank, and Sprinter resources exist but are not used in the normal campaign. Armored and Swarm enemy types do not exist.

### Alternate Modes

- **Challenge scenarios** — **Not implemented**. Possible rule sets:
  - **Click Only:** Defeat enemies by clicking, with no obstacles allowed.
  - **No Turrets:** Walls and support buildings only.
  - **Speed Run:** Finish within a time limit. Scenarios already track best times, but there is no time-limit win condition.
  - **Limited Budget:** Play with a fixed amount of Scrap.
  - **Horde Mode:** Survive as many waves as possible.
- **Endless mode and leaderboards** — **Not implemented**. The idea is to increase difficulty over successive waves and rank runs on leaderboards.

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

### Combat Feedback

- Particle effects and damage numbers are implemented.
- **Screen shake** — **Not implemented**. The existing hit effect shakes individual entities, not the camera.

### Audio

- Simple click sounds, fun turret SFX, occasional survivor yelps.
- Light zombie groans.
- Music is implemented; the aim is a comedic or upbeat apocalyptic soundtrack.

---

## Optional Twitch Integration

- **Survivor naming** — **Implemented**. The `!joinqueue` chat command adds the viewer's Twitch username to the priority pool for survivor names.
- **Wave voting** — **Not implemented**. Viewers could vote on special enemy types for upcoming waves.
- **Viewer points and actions** — **Not implemented**. Viewers could earn stream points and spend them to help or hinder the player, for example by granting bonus Scrap or spawning an elite zombie.

---

## Development Notes

- Built in Godot 4
- Feature-based folder structure using template + config patterns.
- **Resource-based data loading** — **Implemented**. Tech nodes, achievements, and building definitions load from `.tres` resources.
- Component-based architecture (Health, Attack, Buff components).
- Autoload singletons: CurrencyManager, StatsManager, AchievementManager, TechTreeManager, BuildingRegistry, GameManager, MyLogger, AudioManager.
- Current implementation includes XP and Player Level, a branching tech tree, per-slot achievements, scenario completion records and best times, and multiple save slots.
- GitHub repo: [https://github.com/saebyn/zom-nom-defense](https://github.com/saebyn/zom-nom-defense)

---

## Branding

For the title screen and a potential Steam listing.

**Name:** Zom Nom Defense: Click. Aim. Survive.
**Subtitle:** Lighthearted zombie tower defense with a click-to-kill twist.

---

## Tags

Zombies, Tower Defense, Indie, Clicker, Survival, Strategy, Comedy, Twitch Integration
