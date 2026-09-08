# Tech Tree Implementation Checklist

Working document for tracking all `.tres` file changes needed to bring
`Config/TechTree/` and `Config/AttackEffect/` in line with the design in
`tech_tree_design.md`.

**Legend:** `[ ]` = not started · `[x]` = done

---

## Part A – Update Existing TechTree Files

Fields to fix per the design (level, prereqs, exclusivities, building IDs, etc.).

### Offensive

- [ ] **`tur_scrap_shooter.tres`**
  - Leave `scrap_cost = 75` (all scrap costs TBD — will be set in balance pass, but this one is already at a good value for a starting tech)
  - Add `level_requirement = 1`

- [ ] **`tur_boom_barrel.tres`**
  - `level_requirement`: 2 → **3**
  - `prerequisite_tech_ids`: `["tur_scrap_shooter"]` → `["tur_scrap_shooter2"]`
  - `mutually_exclusive_with`: `["tur_molotov_mortar"]` → `["tur_incendiary_barrage"]`
  - Add `achievement_ids = ["ach_place_3"]`

- [ ] **`tur_molotov_mortar.tres`**
  - `prerequisite_tech_ids`: `["tur_scrap_shooter"]` → `["tur_boom_barrel"]`
  - `mutually_exclusive_with`: `["tur_boom_barrel"]` → `[]` (no longer exclusive)
  - Add `achievement_ids = ["ach_kill_100"]`
  - *(level_requirement = 4 is already correct)*

- [ ] **`tur_saw_spitter.tres`**
  - `prerequisite_tech_ids`: `["tur_scrap_shooter"]` → `["tur_scrap_shooter3"]`
  - *(level_requirement = 3 is already correct)*

- [ ] **`tur_zed_zapper.tres`**
  - `prerequisite_tech_ids`: `["tur_saw_spitter"]` → already correct ✓
  - `unlocked_building_ids`: `["zed_zapper"]` → leave as-is (pending rename tracked separately)
  - *(level_requirement = 4 is already correct)*

### Defensive

- [ ] **`ob_crates.tres`**
  - Add `level_requirement = 1`

- [ ] **`ob_oil_slick.tres`**
  - *(level_requirement = 2 and prerequisite_tech_ids = ["ob_crates"] are already correct)*
  - No changes needed ✓

- [ ] **`ob_spike_barricade.tres`**
  - *(level_requirement = 2, prerequisite_tech_ids = ["ob_crates"], achievement_ids = ["ach_place_3"] are already correct)*
  - No changes needed ✓

- [ ] **`ob_electric_fence.tres`**
  - `level_requirement`: 3 → **4**
  - `prerequisite_tech_ids`: `["ob_spike_barricade", "tur_zed_zapper"]` → `["ob_razor_wire"]`
    *(cross-branch tur_zed_zapper dependency demoted to a gameplay synergy, not a hard prereq)*

- [ ] **`ob_zombie_bait_sign.tres`**
  - *(level_requirement = 3 and prerequisite_tech_ids = ["ob_crates"] are already correct)*
  - No changes needed ✓

### Economy

- [ ] **`eco_scrap_recycler.tres`**
  - `level_requirement`: 2 → **3**
  - Remove `prerequisite_tech_ids` if any (branch entry — no prereqs)

- [ ] **`eco_drone_salvager.tres`**
  - `level_requirement`: 3 → **5**
  - `prerequisite_tech_ids`: `["eco_scrap_recycler"]` → `["eco_scrap_recycler3"]`
  - `mutually_exclusive_with`: `["eco_industrial_recycler"]` → `[]`
    *(exclusivity is now megafoundry ⟂ swarm_salvager, not drone_salvager ⟂ industrial_recycler)*

- [ ] **`eco_industrial_recycler.tres`**
  - `level_requirement`: 3 → **5**
  - `prerequisite_tech_ids`: `["eco_scrap_recycler"]` → `["eco_scrap_recycler3"]`
  - `mutually_exclusive_with`: `["eco_drone_salvager"]` → `[]`
    *(no longer exclusively paired — it is now linear prereq to eco_megafoundry)*

- [ ] **`eco_harvest_boost.tres`**
  - `prerequisite_tech_ids`: `["eco_scrap_recycler"]` → `["eco_scrap_recycler2"]`
  - *(level_requirement = 4 is already correct)*

### Support

- [ ] **`sup_overcharger.tres`**
  - `level_requirement`: 2 → **4**

- [ ] **`sup_range_amp.tres`**
  - `level_requirement`: 3 → **5**
  - `prerequisite_tech_ids`: `["sup_overcharger"]` → already correct ✓

- [ ] **`sup_attack_speed_beacon.tres`**
  - `id`: `"sup_cooldown_beacon"` → **`"sup_atk_beacon"`**
  - `display_name`: update to **"Attack Speed Beacon"**
  - `level_requirement`: 3 → **5**
  - `prerequisite_tech_ids`: `["sup_overcharger"]` → `["sup_overcharger2"]`
  - `unlocked_building_ids`: `["cooldown_beacon"]` → `["attack_speed_beacon"]`

- [ ] **`sup_repair_drone.tres`**
  - `level_requirement`: 4 → **6**
  - `prerequisite_tech_ids`: `["sup_attack_speed_beacon"]` → `["sup_atk_beacon2"]`
  - *(achievement_ids = ["ach_lose_5_defenses"] is already correct)*

### Click

- [ ] **`clk_hydraulic_mouse.tres`**
  - Add `level_requirement = 2`

- [ ] **`clk_double_tap.tres`**
  - `prerequisite_tech_ids`: `["clk_hydraulic_mouse"]` → `["clk_hydraulic_mouse2"]`
  - *(level_requirement = 3, achievement_ids = ["ach_click_100"], mutually_exclusive_with = ["clk_shock_click"] are already correct)*

- [ ] **`clk_shock_click.tres`**
  - `prerequisite_tech_ids`: `["clk_hydraulic_mouse"]` → `["clk_hydraulic_mouse2"]`
  - *(level_requirement = 3, achievement_ids = ["ach_click_kills_25"], mutually_exclusive_with = ["clk_double_tap"] are already correct)*

- [ ] **`clk_recoil_dampener.tres`**
  - *(level_requirement = 3 and prerequisite_tech_ids = ["clk_hydraulic_mouse"] are already correct)*
  - No changes needed ✓

### Advanced

- [ ] **`adv_experimental_weapons.tres`**
  - `level_requirement`: 5 → **6**
  - *(achievement_ids = ["ach_kill_500"] and requires_branch_completion = ["Offensive"] are already correct)*

- [ ] **`adv_fortification_mastery.tres`**
  - `level_requirement`: 5 → **6**
  - *(achievement_ids = ["ach_survive_10"] and requires_branch_completion = ["Defensive"] are already correct)*

- [ ] **`adv_synergy_hub.tres`**
  - *(level_requirement = 6, achievement_ids = ["ach_place_50"], requires_branch_completion = ["Support", "Economy"] are already correct)*
  - No changes needed ✓

---

## Part B – Create New TechTree Files

### Offensive (5 new)

- [ ] **`tur_scrap_shooter2.tres`** — Scrap Shooter II
  - `branch_name = "Offensive"`, `level_requirement = 2`
  - `prerequisite_tech_ids = ["tur_scrap_shooter"]`

- [ ] **`tur_scrap_shooter3.tres`** — Scrap Shooter III
  - `branch_name = "Offensive"`, `level_requirement = 3`
  - `prerequisite_tech_ids = ["tur_scrap_shooter2"]`

- [ ] **`tur_incendiary_barrage.tres`** — Incendiary Barrage
  - `branch_name = "Offensive"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["tur_molotov_mortar"]`
  - `mutually_exclusive_with = ["tur_boom_barrel"]`
  - `unlocked_building_ids = ["incendiary_barrage"]`

- [ ] **`tur_blade_storm.tres`** — Blade Storm
  - `branch_name = "Offensive"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["tur_saw_spitter"]`
  - `unlocked_building_ids = ["blade_storm"]`

- [ ] **`tur_arc_nova.tres`** — Arc Nova
  - `branch_name = "Offensive"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["tur_zed_zapper"]`
  - `unlocked_building_ids = ["arc_nova"]`

### Defensive (5 new)

- [ ] **`ob_reinforced_crates.tres`** — Reinforced Crates
  - `branch_name = "Defensive"`, `level_requirement = 2`
  - `prerequisite_tech_ids = ["ob_crates"]`
  - `unlocked_building_ids = ["reinforced_crates"]`

- [ ] **`ob_fortified_wall.tres`** — Fortified Wall
  - `branch_name = "Defensive"`, `level_requirement = 3`
  - `prerequisite_tech_ids = ["ob_reinforced_crates"]`
  - `unlocked_building_ids = ["fortified_wall"]`

- [ ] **`ob_cryo_slick.tres`** — Cryo Slick
  - `branch_name = "Defensive"`, `level_requirement = 3`
  - `prerequisite_tech_ids = ["ob_oil_slick"]`
  - `mutually_exclusive_with = ["ob_razor_wire"]`
  - `unlocked_building_ids = ["cryo_slick"]`

- [ ] **`ob_razor_wire.tres`** — Razor Wire
  - `branch_name = "Defensive"`, `level_requirement = 3`
  - `prerequisite_tech_ids = ["ob_spike_barricade"]`
  - `mutually_exclusive_with = ["ob_cryo_slick"]`
  - `unlocked_building_ids = ["razor_wire"]`

- [ ] **`ob_mega_lure.tres`** — Mega Lure
  - `branch_name = "Defensive"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["ob_zombie_bait"]`
  - `unlocked_building_ids = ["mega_lure"]`
  - Note: prerequisite ID is `ob_zombie_bait` (short form), not `ob_zombie_bait_sign`

### Economy (6 new)

- [ ] **`eco_scrap_recycler2.tres`** — Scrap Recycler II
  - `branch_name = "Economy"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["eco_scrap_recycler"]`

- [ ] **`eco_scrap_recycler3.tres`** — Scrap Recycler III
  - `branch_name = "Economy"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["eco_scrap_recycler2"]`

- [ ] **`eco_megafoundry.tres`** — Megafoundry
  - `branch_name = "Economy"`, `level_requirement = 6`
  - `prerequisite_tech_ids = ["eco_industrial_recycler"]`
  - `mutually_exclusive_with = ["eco_swarm_salvager"]`
  - `unlocked_building_ids = ["megafoundry"]`

- [ ] **`eco_swarm_salvager.tres`** — Swarm Salvager
  - `branch_name = "Economy"`, `level_requirement = 6`
  - `prerequisite_tech_ids = ["eco_drone_salvager"]`
  - `mutually_exclusive_with = ["eco_megafoundry"]`
  - `unlocked_building_ids = ["swarm_salvager"]`

- [ ] **`eco_harvest_boost2.tres`** — Harvest Boost II
  - `branch_name = "Economy"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["eco_harvest_boost"]`

- [ ] **`eco_death_dividend.tres`** — Death Dividend
  - `branch_name = "Economy"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["eco_scrap_recycler3"]`

### Support (5 new)

- [ ] **`sup_overcharger2.tres`** — Overcharger II
  - `branch_name = "Support"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["sup_overcharger"]`

- [ ] **`sup_range_amp2.tres`** — Range Amp II
  - `branch_name = "Support"`, `level_requirement = 6`
  - `prerequisite_tech_ids = ["sup_range_amp"]`

- [ ] **`sup_atk_beacon2.tres`** — Attack Speed Beacon II
  - `branch_name = "Support"`, `level_requirement = 6`
  - `prerequisite_tech_ids = ["sup_atk_beacon"]`

- [ ] **`sup_repair_drone2.tres`** — Auto-Repair Drone II
  - `branch_name = "Support"`, `level_requirement = 7`
  - `prerequisite_tech_ids = ["sup_repair_drone"]`

- [ ] **`sup_target_painter.tres`** — Target Painter
  - `branch_name = "Support"`, `level_requirement = 6`
  - `prerequisite_tech_ids = ["sup_range_amp2"]`
  - `unlocked_building_ids = ["target_painter"]`

### Click (7 new)

- [ ] **`clk_hydraulic_mouse2.tres`** — Hydraulic Mouse II
  - `branch_name = "Click"`, `level_requirement = 3`
  - `prerequisite_tech_ids = ["clk_hydraulic_mouse"]`
  - `player_attack_effect` → `tech_hydraulic_mouse_2.tres`

- [ ] **`clk_hydraulic_mouse3.tres`** — Hydraulic Mouse III
  - `branch_name = "Click"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["clk_hydraulic_mouse2"]`
  - `player_attack_effect` → `tech_hydraulic_mouse_3.tres`

- [ ] **`clk_double_tap2.tres`** — Double Tap II
  - `branch_name = "Click"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["clk_double_tap"]`
  - `player_attack_effect` → `tech_double_tap_2.tres`

- [ ] **`clk_double_tap3.tres`** — Double Tap III
  - `branch_name = "Click"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["clk_double_tap2"]`
  - `mutually_exclusive_with = ["clk_shock_click3"]`
  - `player_attack_effect` → `tech_double_tap_3.tres`

- [ ] **`clk_shock_click2.tres`** — Shock Click II
  - `branch_name = "Click"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["clk_shock_click"]`
  - `player_attack_effect` → `tech_shock_click_2.tres`

- [ ] **`clk_shock_click3.tres`** — Shock Click III
  - `branch_name = "Click"`, `level_requirement = 5`
  - `prerequisite_tech_ids = ["clk_shock_click2"]`
  - `mutually_exclusive_with = ["clk_double_tap3"]`
  - `player_attack_effect` → `tech_shock_click_3.tres`

- [ ] **`clk_recoil_dampener2.tres`** — Recoil Dampener II
  - `branch_name = "Click"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["clk_recoil_dampener"]`

- [ ] **`clk_rapid_fingers.tres`** — Rapid Fingers
  - `branch_name = "Click"`, `level_requirement = 4`
  - `prerequisite_tech_ids = ["clk_hydraulic_mouse3"]`

### Advanced (4 new)

- [ ] **`adv_railgun_mk2.tres`** — Railgun Mk.II
  - `branch_name = "Advanced"`, `level_requirement = 7`
  - `prerequisite_tech_ids = ["adv_experimental_weapons"]`
  - `unlocked_building_ids = ["railgun_mk2"]`

- [ ] **`adv_kill_zone2.tres`** — Kill Zone II
  - `branch_name = "Advanced"`, `level_requirement = 7`
  - `prerequisite_tech_ids = ["adv_fortification_mastery"]`
  - `unlocked_building_ids = ["kill_zone_2"]`

- [ ] **`adv_overload_grid.tres`** — Overload Grid
  - `branch_name = "Advanced"`, `level_requirement = 7`
  - `prerequisite_tech_ids = ["adv_synergy_hub"]`
  - `unlocked_building_ids = ["overload_grid"]`

- [ ] **`adv_click_mastery.tres`** — Click Mastery
  - `branch_name = "Advanced"`, `level_requirement = 6`
  - `requires_branch_completion = ["Click"]`

---

## Part C – Create New AttackEffect Files

- [ ] **`tech_hydraulic_mouse_2.tres`**
  - `damage_multiplier = 1.50`

- [ ] **`tech_hydraulic_mouse_3.tres`**
  - `damage_multiplier = 2.00`

- [ ] **`tech_double_tap_2.tres`**
  - `crit_chance = 0.20`, `crit_multiplier = 2.5`

- [ ] **`tech_double_tap_3.tres`**
  - `crit_chance = 0.30`, `crit_multiplier = 3.0`, `crit_applies_to_splash = true`

- [ ] **`tech_shock_click_2.tres`**
  - `aoe_radius = 5.0`

- [ ] **`tech_shock_click_3.tres`**
  - `aoe_radius = 5.0`, `chain_enabled = true`, `chain_radius = 4.0`, `chain_max_hops = 3`

---

## Part D – Pending Rename (separate task)

These identifiers still use the old "zed" name and need a coordinated rename
once all other work is stable:

- [ ] `tur_zed_zapper.tres` → rename file to `tur_zom_zapper.tres`, update `id` field
- [ ] `unlocked_building_ids = ["zed_zapper"]` in that file → `["zom_zapper"]`
- [ ] Any game code / scene references to `"tur_zed_zapper"` or `"zed_zapper"` building ID
- [ ] Mermaid diagram node ID `tur_zed_zapper` and edge references → `tur_zom_zapper`
- [ ] `tech_tree_design.md` pending-rename note on the catalog row (remove once done)
