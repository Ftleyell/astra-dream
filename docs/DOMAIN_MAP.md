# Mapa de Dominios de Astra Dream (Quick Reference)

Este documento es el mapa de búsqueda rápida ("Single Source of Truth") para desarrolladores y agentes de IA. Permite localizar de forma inmediata dónde reside el balance, la lógica y los recursos de cada subsistema sin necesidad de exploraciones ciegas ni lecturas masivas de código.

---

## 1. Fuentes Únicas de Balance (Data-Driven strictly `.tres`)

> [!IMPORTANT]
> **Prohibido** hardcodear valores numéricos (daño, cadencia, vida, precios, duraciones, radios) en archivos GDScript (`.gd`). Todo ajuste debe realizarse directamente en el recurso exportado `.tres` correspondiente.

| Dominio | Ubicación de Recursos (`.tres`) | Script de Definición de Clase | Descripción |
| :--- | :--- | :--- | :--- |
| **Ítems Pasivos & Activos** | [`data/items/roster/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/items/roster/) | [`core/resources/item_data.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/resources/item_data.gd) | 54 ítems canónicos (.tres) con sus efectos modulares (`ItemEffect`). |
| **Armas & Proyectiles** | [`data/weapons/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/weapons/) | [`core/resources/weapon_data.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/resources/weapon_data.gd) | Estadísticas de disparo, cadencia, velocidad de bala, slots y afinidades. |
| **Pilotos & Talentos** | [`data/characters/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/characters/) | [`core/resources/character_data.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/resources/character_data.gd) | Atributos base de las naves, siluetas vectoriales y árboles de constelación. |
| **Oleadas & Cronograma** | [`data/timeline/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/timeline/) | [`scenes/combat/timeline/encounter_timeline_config.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/timeline/encounter_timeline_config.gd) | Composición de oleadas, umbrales de tiempo, spawn de jefes y crisis. |
| **Progresión & Meta-Stats** | [`data/upgrades/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/upgrades/) | [`scenes/combat/timeline/stat_card_data.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/timeline/stat_card_data.gd) | Cartas de mejora de subida de nivel (Tier 1 a Tier 4). |
| **Tomos de Atributos** | [`data/tomes/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/tomes/) | [`data/tomes/tome_data.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/data/tomes/tome_data.gd) | 11 tomos de estadísticas para build draft (Megabonk-style) y controlador en Player. |
| **Enemigos & Jefes** | [`scenes/combat/enemies/`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/enemies/) | [`scenes/combat/enemies/enemy_base.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/combat/enemies/enemy_base.gd) | Parámetros de vida, velocidad y pools de instanciación. |

---

## 2. Subsistemas Críticos del Núcleo (`core/`)

| Subsistema | Archivo Autoridad | Responsabilidad |
| :--- | :--- | :--- |
| **Arbitraje de Pausa** | [`core/autoloads/pause_arbitrator.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/autoloads/pause_arbitrator.gd) | Autoload que gestiona tokens de pausa concurrentes. **Nunca** asignar `get_tree().paused = true/false` directamente. |
| **Danmaku Zero-Allocation** | [`core/autoloads/bullet_server.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/autoloads/bullet_server.gd) | Renderizado masivo por `MultiMeshInstance2D` y colisiones optimizadas en `PackedFloat32Array`. |
| **Catálogo de Ítems** | [`core/types/item_pool_manager.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/types/item_pool_manager.gd) | Cargador dinámico desde `data/items/roster/`, ponderación por rareza y pools de tiendas/cofres. |
| **Persistencia & Perfil** | [`core/autoloads/save_manager.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/autoloads/save_manager.gd) | Guardado modular (perfil, run activa, estadísticas, cosméticos) en `user://`. |
| **Audio Anti-Fatiga** | [`core/autoloads/audio_manager.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/autoloads/audio_manager.gd) | Concurrencia de SFX, pitch aleatorizado y atenuación dinámica. |
| **Buses de Eventos** | [`core/autoloads/event_bus.gd`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/core/autoloads/event_bus.gd) | Desacoplamiento de señales globales de combate y metajuego. |

---

## 3. Arquitectura Estándar de Modales (`BaseModal`)

Todo nuevo modal o ventana emergente de decisión DEBE extender [`BaseModal`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scenes/ui/components/base_modal.gd).

### Reglas de Modales:
1. **Herencia:** `extends BaseModal`
2. **Definir Token:** Asignar `modal_token = &"mi_modal"` en `_ready()`.
3. **Apertura:** Usar `open_modal()` (o invocar `super.open_modal()` si se personaliza).
4. **Cierre:** Invocar `close_modal()` (o `super.close_modal()`).
5. **Beneficios Automáticos:**
   - Adquisición y liberación de pausa mediante `PauseArbitrator` sin despausar prematuramente si otros menús están abiertos.
   - Sincronización automática con el `CombatStatsDock` del HUD lateral.
   - Período de gracia contra clicks involuntarios (`mouse_grace_period`).
   - `process_mode = PROCESS_MODE_ALWAYS` asegurado en `_enter_tree()`.

---

## 4. Protocolo de Verificación Automatizada (Anti-Hang Shield)

> [!WARNING]
> En Godot 4 headless, los fallos de `assert()` no cierran el proceso del motor si no hay un temporizador inmune. **Nunca** ejecutar comandos `godot --headless` sin temporizador de seguridad o sin el arnés de pruebas.

### Cómo ejecutar pruebas:

- **Batería Central de Regresión (11 suites críticas en ~33s):**
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
  ```

- **Ejecutar una Suite Específica con Detección de Cuelgues:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "tests/test_weapons_runner.tscn"
  ```

- **Crear Nuevas Suites de Test:**
  Toda nueva suite de test DEBE extender [`BaseTestSuite`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/tests/base_test_suite.gd) y llamar a `super._ready()`.
