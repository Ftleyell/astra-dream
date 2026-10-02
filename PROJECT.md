# Project: Astra Dream Integral Rework

## Architecture
Astra Dream is a modular Godot 4.7.2 roguelite danmaku game. The integral rework reorganizes five core systems:
1. **Progression & Economy**: `StatDeckManager` for 3-card level-up offers with +25-30% impact; removal of flat projectile bonuses; `SatelliteShop` restricted to 1 re-roll per satellite visit; rebalanced credit drops and item/weapon prices.
2. **Weapons & Passives**: `WeaponController` capped at 4 slots with replacement modal on 5th weapon acquisition; rival pilot drops yielding Level 1 weapons requiring an open slot; `ItemPoolManager` expanded with 6 reactive proc items and 3 explicit anti-synergy items hooked into `InventoryComponent`.
3. **Visuals & Combat Balance**: `BulletServer` and `danmaku_bullet.gdshader` overhauled for isotropic spherical orbs with 1:1 physical hitbox alignment; weapon shader modulate-alpha multiplying (`COLOR *= COLOR`) to prevent visual popping and HDR color blowouts; adaptive boss health scaling and burst compression in `take_damage()` ensuring a 20-55s active combat floor.
4. **Automated Headless Test Suite**: Full headless verification suite executed via `Godot_v4.7.2-stable_win64_console.exe --headless` validating all rework requirements with exit code 0.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | 3-Card Level-Up Offer | Offer exactly 3 cards instead of 4 in StatDeckManager and LevelUpModal | M1 | ORIGINAL_REQUEST R1 |
| 2 | Stat Card Impact (+25-30%) | Common stat cards grant +25-30% dmg, +20-25% cadence, +5-6 armor, etc. | M1 | ORIGINAL_REQUEST R1 |
| 3 | Remove Universal Flat Projectile | Eliminate card_proj_up_1/2 from common pool, shifting to Arcanas/overclock | M1 | ORIGINAL_REQUEST R1 |
| 4 | Clean Card UI (Instant Read) | Compact card presentation with 64x64 icon, 26pt hero value, minimal text | M1 | ORIGINAL_REQUEST R1 |
| 5 | Satellite Shop 1 Re-roll Limit | Restrict satellite shop to 1 re-roll per visit with disabled button feedback | M1 | ORIGINAL_REQUEST R2 |
| 6 | Credit Deflation & Rebalanced Prices | Reduce common enemy credit drops; calibrate shop prices (weapons 120-150C, passives 40-75C) | M1 | ORIGINAL_REQUEST R2 |
| 7 | 4 Weapon Slots Cap | Restrict WeaponController.MAX_WEAPON_SLOTS to 4 | M2 | ORIGINAL_REQUEST R3 |
| 8 | Weapon Replacement Flow | Prompt player to replace or discard when acquiring a 5th weapon (Shop & Rival drop) | M2 | ORIGINAL_REQUEST R3 |
| 9 | Rival Pilot Loot at Level 1 | Rival signature weapon drops at Level 1 and respects slot capacity | M2 | ORIGINAL_REQUEST R3 |
| 10 | 6 Reactive Proc Items | Implement Tesla Coil, Kinetic Plating, Phase Thruster, Retaliation Swarm, Entropy Catalyst, Phase Inverter | M2 | ORIGINAL_REQUEST R3 |
| 11 | Anti-Synergy / Penalty Items | Implement 3 items with distinct penalties/trade-offs (Glass Reactor, Heavy Capacitor, Tachyon Piercer) | M2 | ORIGINAL_REQUEST R3 |
| 12 | Danmaku Spherical Bullet Shader | Isotropic circular Euclidean distance, glowing core, contrast halo rim in danmaku_bullet.gdshader | M3 | ORIGINAL_REQUEST R4 |
| 13 | 1:1 Bullet Hitbox Alignment | Adjust visual scale in BulletServer (radius / 16.0) matching physical collision radius | M3 | ORIGINAL_REQUEST R4 |
| 14 | Boss Adaptive Health Scaling | Scaled base HP + player offensive power scaling + burst damage compression in take_damage() | M3 | ORIGINAL_REQUEST R4 |
| 15 | Weapon Shader Modulate Fix | Multiply shader COLOR by incoming CanvasItem COLOR (modulate:a) in beam and slash shaders | M3 | ORIGINAL_REQUEST R5 |
| 16 | HDR Overlap Blowout Prevention | Soft-clamp additive shader energy to prevent screen blowouts on weapon overlap | M3 | ORIGINAL_REQUEST R5 |
| 17 | Headless Verification Test Suite | Headless automated suite covering all R1-R5 acceptance criteria exiting with code 0 | M4 | ORIGINAL_REQUEST Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Level-Up Deck & Economy Rework | Features 1, 2, 3, 4, 5, 6 | none | DONE |
| M2 | Weapon Slots, Passives & Rival Loot | Features 7, 8, 9, 10, 11 | M1 | PLANNED |
| M3 | Spherical Danmaku, Shaders & Boss Scaling | Features 12, 13, 14, 15, 16 | none | PLANNED |
| M4 | Automated Headless Test Suite & Acceptance | Feature 17 + Regression Testing of all suites | M1, M2, M3 | PLANNED |

## Interface Contracts

### StatDeckManager ↔ LevelUpModal
- `offer_cards(char_stats: CharacterStats, level: int, count: int = 3) -> void`
- Signal `card_offered(cards: Array[Dictionary])` emitting array of size 3.
- Card dictionary structure:
  ```gdscript
  {
      "id": StringName,
      "title": String,
      "stat": StringName,
      "val": float,
      "pct": bool,
      "tier": Enums.Tier,
      "icon_path": String
  }
  ```

### SatelliteShop ↔ Player
- `max_rerolls_per_satellite: int = 1`
- `rerolls_used_this_visit: int = 0`
- `can_reroll() -> bool`: returns `rerolls_used_this_visit < max_rerolls_per_satellite and current_credits >= reroll_cost`
- On reroll: `player.run_credits = current_credits`, button disabled with text `[AGOTADO (1/1)]`.

### WeaponController ↔ WeaponSwapModal
- `const MAX_WEAPON_SLOTS: int = 4`
- `is_full() -> bool`: returns `equipped_weapons.size() >= MAX_WEAPON_SLOTS`
- `replace_weapon(slot_index: int, new_weapon_data: WeaponData) -> bool`
- Signal `swap_requested(incoming_weapon: WeaponData, on_replaced: Callable, on_cancelled: Callable)`

### InventoryComponent ↔ Player & HitContext
- `process_dash_procs(source_entity: Node) -> void`
- `process_take_damage_procs(incoming_damage: float, source_entity: Node) -> void`
- `process_kill_procs(target_entity: Node) -> void`
- Reactive items hook through `ItemEffect.execute(context, stack_count, source_entity)` using `HitContext.fork_child_hit()` with `depth < 4`.

### BulletServer ↔ danmaku_bullet.gdshader
- QuadMesh size: `Vector2(32.0, 32.0)`
- Instance scale in `bullet_server.gd`: `radius[i] / 16.0` (yields exact pixel radius = `radius[i]`)
- Shader UV center: `p = UV - vec2(0.5)`
- Distance metric: `float dist = length(p) * 2.0; // 0.0 at center, 1.0 at edge`
- Visual circle: `step(dist, 1.0)` with soft anti-aliased rim, incandescent core (`dist < 0.35`), and dark contrast halo (`0.75 < dist < 1.0`).

### Bosses ↔ BossScalingManager / main_game.gd
- Boss base exports remain unchanged (`1600.0`, `2400.0`, `3200.0`, `4500.0`) for unit test backward compatibility.
- At spawn time in `main_game.gd`: apply scaling multiplier based on wave and player offensive DPS.
- In boss `take_damage()`: soft-cap maximum single-instance damage to `max_health * 0.08` (8% max HP floor) preventing sub-second burst cheese while rewarding sustained dodging.

## Code Layout
- `core/types/stat_deck_manager.gd`: Deck offerings, common cards, rarity weights.
- `scenes/ui/level_up_modal.gd` & `.tscn`: 3-card clean visual presentation.
- `scenes/combat/satellite/satellite_shop.gd`: 1-reroll cap, pricing logic.
- `scenes/combat/player/weapon_controller.gd`: 4 slots cap, weapon replacement methods.
- `scenes/ui/modals/weapon_swap_modal.gd` & `.tscn`: 5th weapon acquisition replacement prompt.
- `core/types/inventory_component.gd`: Proc event hooks (dash, take damage, kill).
- `core/types/item_pool_manager.gd`: 6 proc items + 3 anti-synergy items.
- `data/items/item_effect.gd` & subclasses: Specific reactive proc behaviors.
- `core/shaders/danmaku_bullet.gdshader`: Spherical orb shader.
- `core/autoloads/bullet_server.gd`: 1:1 bullet hitbox scale.
- `core/shaders/laser_plasma_beam.gdshader` & `dimensional_slash_blade.gdshader`: Modulate alpha multiplier fix.
- `scenes/combat/main_game.gd`: Adaptive boss health initialization.
- `tests/`: Automated headless test runners and suites.
