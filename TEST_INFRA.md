# E2E Test Infra: Astra Dream Integral Rework

## Test Philosophy
- Requirement-driven, opaque-box and headless verification using Godot 4.7.2.
- Binary invocation:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . <runner.tscn>`
- Expected outcome: All tests exit cleanly with exit code 0.

## Feature Inventory Test Coverage
| # | Feature | Target Component | Verification Method |
|---|---------|------------------|---------------------|
| 1 | 3-Card Level-Up Offer | `StatDeckManager` | Offer cards across 10 levels, assert offer size == 3 |
| 2 | High-Impact Stat Bonuses | `StatDeckManager` | Assert common tier 1 damage >= 0.25, cadence >= 0.20, armor >= 5.0 |
| 3 | No Flat Universal Projectiles | `StatDeckManager` | Assert card_proj_up_1 / card_proj_up_2 absent from common offer pool |
| 4 | Clean Card UI Layout | `LevelUpModal` | Assert 3 card nodes present, hero badge text formatting |
| 5 | Satellite Shop 1 Re-roll Cap | `SatelliteShop` | Assert 1st reroll succeeds, 2nd reroll blocked, button disabled |
| 6 | Credit Deflation & Costs | `SatelliteShop` & Drops | Assert weapons >= 120C, passives >= 40C, common enemy drop rate reduced |
| 7 | Max 4 Weapon Slots | `WeaponController` | Assert 4 weapons equip, 5th weapon rejected or triggers replacement |
| 8 | Weapon Replacement Flow | `WeaponController` | Assert `replace_weapon(idx, new_weapon)` replaces existing weapon correctly |
| 9 | Rival Pilot Level 1 Weapon | `RivalPilotBoss` / Rewards | Assert rival weapon dropped is Level 1 and respects slot capacity |
| 10 | 6 Reactive Proc Items | `InventoryComponent` | Assert procs trigger on dash, damage taken, and crits |
| 11 | Anti-Synergy / Penalty Items | `ItemPoolManager` | Assert penalty items apply both positive and negative stat trade-offs |
| 12 | Danmaku Spherical Bullet Shader | `danmaku_bullet.gdshader` | Assert isotropic math and radius scale ratio `radius / 16.0` |
| 13 | Weapon Shader Alpha Multiply | Weapon Shaders | Assert `COLOR *= COLOR` modulation in shader sources |
| 14 | Boss Health Scaling & Floor | Bosses / `take_damage` | Assert burst damage cap and survival floor logic |

## Test Architecture
- Test Suite Script: `tests/test_rework_suite.gd`
- Test Runner Scene: `tests/test_rework_runner.tscn`
- Regression Run: Run all pre-existing suites:
  - `tests/test_weapons_runner.tscn`
  - `tests/test_domain_bosses_runner.tscn`
  - `tests/test_narrative_and_rival_pilots_runner.tscn`
  - `tests/test_all_stats_runner.tscn`
  - `tests/test_run_stats_and_shop_inventory_runner.tscn`
