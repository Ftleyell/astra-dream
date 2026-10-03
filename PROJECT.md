# Project: Astra Dream — Integral Architecture & Balance Roadmap

## Architecture Overview
Astra Dream es un juego modular roguelite danmaku en Godot 4.7.2. Tras el rework integral, los sistemas centrales están regidos por arquitectura data-driven, zero-allocation y desacople modular:

1. **Documentación Oficial de Balance (`docs/balance/`):**
   - [Arsenal y Progresión de Armas](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/balance/weapons.md) (8 armas, Lv1 a Lv5, +1 proy/nivel, swap y reciclaje).
   - [Objetos, Pasivas y Arcanas](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/balance/items_and_passives.md) (Level-up +25-30%, 24 ítems de satélite con tradeoffs y procs, 24 arcanas).
   - [Heroínas, Dashes y Talentos](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/balance/pilots_and_talents.md) (Stats base de las 6 pilotos, dashes únicos y árboles de talentos).
   - [Oleadas, Enemigos y Colosos](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/balance/waves_and_bosses.md) (Cronograma Waves 1-16, colosos de dominio, rivales y escalado adaptativo).
   - [Economía y Recursos](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/balance/economy.md) (Créditos, biomasa, materia oscura, 1 reroll en tienda satelital y gacha).

2. **Guías Técnicas de Arte (`docs/art/`):**
   - [Lienzos, Resoluciones y Anclas](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/art/canvas_and_anchors.md)
   - [Personajes, Skins y Armas](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/art/characters_and_skins.md)
   - [Enemigos, Jefes y Telegraphs](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/art/enemies_and_bosses.md)
   - [Entornos, Destructibles y VFX](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/art/environments_and_vfx.md)

---

## Milestones de Desarrollo

| # | Hito | Alcance | Estado |
|---|---|---|:---:|
| **M1** | Level-Up Deck & Economía | Oferta de 3 cartas (+25-30%), límite de 1 reroll en satélite, deflación de créditos | **DONE** |
| **M2** | Armas, Pasivas y Loot de Rivales | Tope de 4 armas, modal de swap, 24 ítems de satélite, drops Lv1 de rivales | **DONE** |
| **M3** | Danmaku Esférico, Shaders & Escalado | BulletServer esférico 1:1, shaders aditivos modulados, escalado adaptativo de colosos | **DONE** |
| **M4** | Suite Headless Automatizada | Batería de tests headless con exit code 0 validando requerimientos | **DONE** |
| **M5** | Limpieza, Documentación de Balance y Arte | Purga a backup externo, fichas técnicas compactas y hub `docs/balance/` | **DONE** |
| **M6** | Modularización Radical & Zero-Context Kit | Desacople de `main_game.gd`, `hub_world.gd` y `save_manager.gd`, arquitectura data-driven, kit Zero-Context (`ARCHITECTURE.md`, `EXTENDING_THE_GAME.md`) y pipeline de arte/chromas | **DONE** |
| **M7** | Balance Fino de Combate & Feedback | Calibración de las 8 armas en `.tres`, curvas de oleadas 1-16, colosos adaptativos, economía de biomasa y feedback de impacto/SFX | **IN PROGRESS** |

---

## 📖 Kit Maestro de Documentación Zero-Context

- **[Guía y Árbol Maestro Zero-Context (`docs/architecture/zero_context_architecture_and_file_tree.md`)](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/architecture/zero_context_architecture_and_file_tree.md):** Árbol exhaustivo de archivos, mapa de responsabilidades, flujos Zero-Allocation y diagramas de subsistemas.
- **[Arquitectura Integral del Sistema (`ARCHITECTURE.md`)](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/ARCHITECTURE.md):** Mapa visual 3D/2D, ciclo de vida de runs, contratos `HitContext`/`take_damage` y servidores zero-allocation.
- **[Guía de Extensión para Desarrolladores (`EXTENDING_THE_GAME.md`)](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/EXTENDING_THE_GAME.md):** Recetas paso a paso para añadir heroínas, armas, jefes danmaku y tests unitarios.
- **[Guía Rápida de Balanceo (`docs/balance/QUICK_BALANCE_GUIDE.md`)](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/balance/QUICK_BALANCE_GUIDE.md):** Ajuste de daño, salud, oleadas y tiendas puramente mediante recursos `.tres`.
- **[Pipeline de Arte y Chromas (`docs/art/asset_generation_and_chromas.md`)](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/docs/art/asset_generation_and_chromas.md):** Generación cenital 90° con IA y recoloreo en masa con protección de piel y ojos.

---

## Contratos de Interfaz Clave

### EncounterDirector ↔ EncounterTimelineConfig (`.tres`)
* Duración de oleadas, hitos de colosos, rivales y parámetros de escalado inyectados vía recurso exportado.

### WeaponController ↔ Player & HUD
* Límite estricto de 4 ranuras (`MAX_WEAPON_SLOTS = 4`).
* Emisión reactiva de `weapon_slots_changed(weapons)` para actualización en HUD sobre la fila de habilidades.
* Reemplazo de arma con herencia de nivel y otorgamiento de créditos de reciclaje (`35c` a `95c`).
