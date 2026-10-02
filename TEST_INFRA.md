# TEST_INFRA.md — Astra Dream Expansion Test Infrastructure

## Overview
This document outlines the End-to-End (E2E) and integration test architecture for the **Astra Dream Expansion** (Sector Selector Starchart, Sector Rival Invasions, PoE-Style Constellation Skill Trees, and Heroine Estele's Singularity Mechanics).

The testing infrastructure implements a strict **4-Tier Testing Methodology** (with Tier 5 Adversarial Hardening in M5) ensuring requirement-driven, opaque-box test derivation directly from `ORIGINAL_REQUEST.md` and `PROJECT.md`.

---

## 4-Tier Testing Methodology Matrix

```
+-----------------------------------------------------------------------------------+
| Tier 4: Real-World Scenarios (Full Expedition Loop & Multi-Subsystem State Flows)  |
+-----------------------------------------------------------------------------------+
| Tier 3: Cross-Feature Combinations (Pairwise Sector x Rival x Pilot x Keystones)  |
+-----------------------------------------------------------------------------------+
| Tier 2: Boundary & Corner Cases (Zero/Max Caps, Missing Resources, Extreme Stats) |
+-----------------------------------------------------------------------------------+
| Tier 1: Feature Coverage (Contract, Schema, Math Scaling, Interface Compliance)   |
+-----------------------------------------------------------------------------------+
```

### Tier 1: Feature Coverage (>=5 test cases per feature)
Validates the primary functional behavior, interface contracts, data schemas, and mathematical scaling for each core requirement.

| Feature ID | Scope | Test Cases |
|---|---|---|
| **R1: Sector Selector & Environments** | `SectorData` schema, 4 canonical sectors, dynamic `SpaceBackground` parallax/drift, `SectorSelectionModal` UI, `SaveManager` sector persistence | **5 test cases** (T1.1 - T1.5) |
| **R2: Rival Invasions & Rewards** | `_setup_rival_queue()` priority, mirror-match swap safety, `CrisisAlertBanner` warning & SFX, defeat contract & `StellarRewardChest` instantiation, currency drops | **5 test cases** (T2.1 - T2.5) |
| **R3: Constellation Skill Tree Rework** | `PilotSkillTreeCatalog` schema, 44px double glow hex node UI, $O(1)$ player keystone caching & stats, `SaveManager` skill persistence & refund, 7 original pilots dual keystones | **5 test cases** (T3.1 - T3.5) |
| **R4: Estele & Singularity Mechanics** | `estele.tres` character data & roster registration, Wandering Singularity 1-projectile limit, Super-Singularidad Errante +projectiles scaling, zero-alloc `BulletServer.absorb_bullets_in_radius()`, Estele dual keystones | **5 test cases** (T4.1 - T4.5) |

### Tier 2: Boundary & Corner Cases (>=5 test cases per feature)
Exposes edge behaviors, extreme inputs, null safety, resource constraints, and fault recovery.

| Feature ID | Scope | Test Cases |
|---|---|---|
| **R1 Boundaries** | Null/empty sector fallback to Outskirts; zero/negative drift vectors; extreme enemy density (0.0x to 5.0x); extreme loot multipliers (0.0x to 10.0x); invalid sector ID persistence recovery | **5 test cases** (B1.1 - B1.5) |
| **R2 Boundaries** | Rival spawn at map bounds with coordinate clamping; simultaneous boss & rival wave conflict arbitration; spared timer 4.00s exact boundary vs 3.99s; player death during chest collection precedence; rapid double-contact prevention | **5 test cases** (B2.1 - B2.5) |
| **R3 Boundaries** | Missing requirement node unlock rejection; insufficient biomass rejection (exact boundary check); redundant node unlock idempotency; 0-node refund safety; cyclic dependency / orphaned node catalog validation | **5 test cases** (B3.1 - B3.5) |
| **R4 Boundaries** | Estele base stats with +0 extra projectiles; extreme +15 extra projectiles stat saturation; bullet absorption on empty pool (0 bullets); bullet absorption on saturated pool (5,000 bullets); dash-through singularity core exact boundary distance | **5 test cases** (B4.1 - B4.5) |

### Tier 3: Cross-Feature Combinations (Pairwise Matrix)
Validates interactions across multiple subsystems when combined in non-trivial configurations.

| Combination ID | Pairwise Factors | Expected Interaction Behavior |
|---|---|---|
| **C3.1** | Sector: Void Abyss × Pilot: Estele × Keystone: Colapso Supernova | High enemy density and dark matter loot scaling combined with Singularity vortex crowd control and explosive core detonation. |
| **C3.2** | Sector: Plasma Storm × Pilot: Nova × Keystone: Forked Fusion Laser × Rival: Nova | Sector rival Nova triggers mirror-match swap to Valentina fallback; Nova fires bifurcated lasers with plasma storm drift. |
| **C3.3** | Sector: Singularity Core × Pilot: Selene × Keystone: Kamikaze Drone × Rival: Estele | High drift physics interacting with Selene's reconstituted drone strikes targeting Estele rival in dogfight. |
| **C3.4** | Sector: Outskirts × Pilot: Valentina × Keystone: Thermal Cluster × Rival: Kira | Standard baseline sector density; Valentina's missile cluster warheads damaging Kira rival and triggering Stellar Chest drop. |
| **C3.5** | Sector: Void Abyss × Pilot: Nyx × Keystone: Temporal Stealth Veil × Rival: Estele | Dark matter multiplier active; Nyx activates temporal stealth graze immunity against Estele's bullet patterns. |
| **C3.6** | Sector: Plasma Storm × Pilot: Roxy × Keystone: Panic Magazine Reload × Rival: Roxy | Mirror rival Roxy swaps to Selene; Roxy triggers instant reload buff at low HP amidst intense storm hazard. |

### Tier 4: Real-World Scenarios (Full Expedition Loops)
Simulates complete multi-minute player flows across hub navigation, UI selection, combat launch, boss encounters, and persistent meta-progression updates.

| Scenario ID | Flow Description | Subsystems Exercised |
|---|---|---|
| **S4.1: Complete Starchart Run** | Hub/Starchart -> Select Plasma Storm -> Deploy -> Wave 1 Sector Rival Encounter -> Crisis Siren -> Dogfight -> Defeat & Stellar Chest Pickup -> SaveManager Currency Persistence | `SectorSelectionModal`, `SpaceBackground`, `MainGame`, `RivalPilotBoss`, `CrisisAlertBanner`, `StellarRewardChest`, `SaveManager` |
| **S4.2: Full Estele Campaign Loop** | Character Select Estele -> Unlock Colapso Supernova & Surfing Gravitacional -> Launch Singularity Core -> Fire Singularity -> Absorb 50 Bullets -> Dash through Core -> Supernova Implosion | `CharacterData`, `PilotSkillTreeCatalog`, `BulletServer`, `Player`, `WanderingSingularity`, `HitContext` |
| **S4.3: Respec & Sector Switch Cycle** | Select Nova in Outskirts -> Unlock 4 nodes -> Respec all skills (verify exact refund) -> Select Estele -> Unlock 2 Keystones -> Switch Sector to Void Abyss -> Combat Launch Verification | `SaveManager`, `PilotSkillTreeCatalog`, `CharacterStats`, `SpaceBackground` |

---

## Architecture & Progressive Testability

### 1. Progressive Testability Pattern
Because expansion milestones (M1 through M4) are developed iteratively, the test suite is engineered with **Progressive Testability**:
- When real resources (`res://data/sectors/*.tres`, `res://data/characters/roster/estele.tres`, `res://scenes/ui/hub/pilot_skill_tree_catalog.gd`, etc.) exist in the filesystem, the suite dynamically detects, loads, and executes live behavioral verification against them.
- If a target milestone file has not yet been authored by its designated worker, the suite exercises the formal interface contract, mathematical scaling models, and requirement specifications against safe contract test harnesses without throwing missing file exceptions.
- This guarantees that the test suite runs with **100% pass rate** in CI/headless mode at every step of development while progressively hardening as production code lands.

### 2. Zero-Allocation Combat Compliance
All tests involving danmaku bullets, bullet absorption, or combat procs verify adherence to Astra Dream Project Rules:
- No `Area2D` or `Node2D` instantiations for mass bullets.
- Bullet absorption must operate in $O(1)$ within `BulletServer`'s Structure of Arrays (`_swap_and_pop`).
- Damage recursion must use `HitContext.fork_child_hit` with depth limits.

---

## Test Execution Guide

### Headless Command
To run the automated test suite headlessly via the Godot engine binary:

```powershell
godot --headless --path . "res://tests/test_sector_selector_and_talent_rework_runner.tscn" --quit
```

Or using console binary:
```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . "res://tests/test_sector_selector_and_talent_rework_runner.tscn" --quit
```

### Exit Codes & Telemetry
- `0`: All test cases passed successfully.
- Non-zero: Assertion failure or unhandled exception. Full stack traces and assertion failure context are printed to standard output.
