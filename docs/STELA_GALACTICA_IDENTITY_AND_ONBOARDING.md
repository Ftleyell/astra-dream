# Identidad *Stela Galactica*, Transición Singularidad y Tutorial de Hub 3D

> Documentación viva del flujo de arranque, identidad visual y onboarding en producción (`Alpha 0.1`).

---

## 1. Máquina de Estados Unificada sobre Cosmos Engine Vivo

La pantalla de título, la materialización de la Estación Astral y el combate comparten **una única instancia viva de `CosmosCombatEnvironment`** dentro de `MainGame` (`scenes/combat/main_game.gd`), evitando recrear el fondo cósmico al pulsar `JUGAR` o al volver a `Título`:

```text
project.godot (main_scene)
  └─> title_screen.tscn (Boot Preloader silencioso sin Singularidad, threaded load)
        └─> MainGame (EntryMode.TITLE · fade-in continuo desde vacío cósmico)
              ├─ TITLE_ACTIVE ──(JUGAR / Enter)──> HUB_MATERIALIZING ──> HUB_ACTIVE
              │      ▲   └─(Pre-calentado diferido Hub 3D tras reveal)       │
              │      └────────────────(Botón "Título" / Seamless)───────────┤
              │                                                               ▼
              └─(REANUDAR INCURSIÓN)──> SceneTransition [Singularidad] ─> COMBAT_LIVE
                                                                   (Despegue Zero-Rail)
```

| Estado / Modo | Responsable | Qué hace |
|---|---|---|
| **Boot Preloader** | [`title_screen.gd`](../scenes/ui/title_screen/title_screen.gd) | Carga `MainGame (EntryMode.TITLE)` en segundo plano con `ResourceLoader.load_threaded_request` **sin Singularidad**, evitando resets falsos ni cuelgues al abrir el juego. |
| **`TITLE_ACTIVE`** | [`combat_title_session_controller.gd`](../scenes/combat/controllers/combat_title_session_controller.gd) | Fade-in continuo sobre el Cosmos vivo, ilumina el logo con `CosmicLightingSampler`, pre-calienta de forma diferida el Hub 3D al finalizar el reveal del logo y muestra `TitleMenuOverlay` (`JUGAR` siempre primero y con foco inicial para `[Enter]`, `REANUDAR INCURSIÓN` debajo si hay partida guardada, `AJUSTES`, `Notas del Parche`, `SALIR`). |
| **`HUB_MATERIALIZING`** | `CombatTitleSessionController` + `AstralStationHub` | Disuelve el logo, desliza la cámara, materializa el Hub 3D del centro hacia afuera (`demat_invert = true`) y hace aterrizar a Valentina con Alas 3D y `HubLandingRippleVFX`. |
| **`HUB_ACTIVE`** | [`combat_hub_session_controller.gd`](../scenes/combat/controllers/combat_hub_session_controller.gd) | Libre recorrido sobre el Hub 3D, estaciones/modales y `HubTutorialDirector` (primera visita o `? Guía` / `[F1]`). |
| **`DEPARTING_DISSOLVE` → `COMBAT_LIVE`** | `CombatHubSessionController` | Despegue radial 8-dir sin pausa ni diálogo de prólogo; `CombatBootstrapper` otorga `+50` créditos iniciales de forma silenciosa en entradas directas. |

---

## 2. Logotipo *Stela Galactica* en 4 Capas y Pipeline de Arte

- **Escenario modular:** [`StelaLogoStage`](../scenes/ui/title_screen/components/stela_logo_stage.gd)
  1. `AstrolabeRingsRect` ([`stela_logo_astrolabe_rings.gdshader`](../shaders/ui/stela_logo_astrolabe_rings.gdshader)): anillos procedurales contrarrotativos reactivos al rim del Cosmos.
  2. `MedallionRect` ([`stela_logo_cel_lit.gdshader`](../shaders/ui/stela_logo_cel_lit.gdshader)): medallón astrolabio independiente en rotación con compensación angular del normal map (`sprite_rotation_rad`).
  3. `LogoHeroRect` (`stela_logo_cel_lit.gdshader`): tipografía `STELA GALACTICA` cel-shaded con normal map, máscaras `R=Metal, G=Cian, B=AO`, barrido periódico y disolución radial.
  4. `EnergySlashRect` ([`stela_logo_energy_slash.gdshader`](../shaders/ui/stela_logo_energy_slash.gdshader)): tajo energético diagonal por delante de la tipografía.
- **Balance Data-Driven:** [`data/ui/stela_logo_vfx_config.gd`](../data/ui/stela_logo_vfx_config.gd) → [`default_stela_logo_vfx_config.tres`](../data/ui/default_stela_logo_vfx_config.tres).
- **Assets compilados (`assets/ui/`):** `stela_galactica_{logo,medallion}_{albedo,normal,masks}.png`.
- **Procesador CLI:** [`tools/process_stela_logo.py`](../tools/process_stela_logo.py) (chroma-key global con preservación de huecos internos, despilling, auto-crop y mapas normales/máscaras).

---

## 3. Transición Singularidad (`SceneTransition`)

- **Autoload:** [`core/autoloads/scene_transition.gd`](../core/autoloads/scene_transition.gd) delega en [`SingularityTransitionPresenter`](../core/systems/singularity_transition_presenter.gd) y [`singularity_transition.gdshader`](../shaders/ui/singularity_transition.gdshader).
- **3 Fases sin texto ni barras:**
  1. `Big Crunch`: contracción gravitacional del snapshot de pantalla hacia un punto blanco incandescente.
  2. `Singularity Hold`: punto vivo absorbiendo partículas radiales mientras corre `ResourceLoader.load_threaded_request()`.
  3. `Big Bang`: onda expansiva refractiva que revela la escena destino.
- **Cuándo se usa:** únicamente al cambiar/recargar escena por reset real de universo (retorno al Hub o Título desde Combate/Pausa/Game Over y botón `REANUDAR INCURSIÓN`). El arranque frío desde `title_screen.tscn` y el paso `Título ↔ Hub ↔ Combate` ocurren de forma continua sin Singularidad ni pantalla de carga.
- **Balance Data-Driven:** [`default_singularity_transition_config.tres`](../data/ui/default_singularity_transition_config.tres) y [`default_title_to_hub_sequence_config.tres`](../data/ui/default_title_to_hub_sequence_config.tres).

---

## 4. Tutorial / Debrief del Hub 3D con Mascota

- **Orquestador:** [`HubTutorialDirector`](../scenes/ui/hub/astral_station/components/hub_tutorial_director.gd) + [`HubTutorialHighlightController`](../scenes/ui/hub/astral_station/components/hub_tutorial_highlight_controller.gd).
- **Presentación:** usa **Dialogic nativo** con retrato grande de la mascota equipada (`join <pet> right` en `mochi`/`kuro`/`luna`/`pip`/`cosmo`), voz vía `DialogicMumbleBridge`, atajo `[ESC]` / `DialogueSkipOverlay` y **cero** oscurecimiento de pantalla ni pausa del árbol (`PROCESS_MODE_ALWAYS`).
- **Destacado en 3D:** inyecta `tutorial_highlight_pulse` y `tutorial_highlight_color` sobre las mallas 3D del Hub (`hub_arcsys_prop_3d`, `hub_arcsys_outline_3d`, `hub_capsule_dais_3d`, `hub_hardlight_bridge_3d`), incluyendo estaciones en estado `CALIBRATING` y los puentes radiales en el paso final.
- **Activación y persistencia:**
  - Se lanza automáticamente tras la primera entrada al Hub (`SaveManager.is_hub_tutorial_completed() == false`) y marca `hub_tutorial_completed = true` en `user://profile_data.json` (`ProfileSettingsData` / `ProfileStorage`) al finalizar o saltar.
  - Puede repetirse en cualquier momento con el botón **`? Guía`** (`AstralStationHUD`) o la tecla **`[F1]`** en modo libre.
  - **Blindaje en `MainGame`:** `_on_dialogic_timeline_started`, `_on_dialogic_timeline_ended` y `_on_dialogic_signal` ignoran eventos mientras `is_hub_mode_active()` o `is_title_or_materializing_active()` sea verdadero para que `CombatNarrativeDirector` no pause el árbol ni muestre el HUD de combate.
- **Secuencia Data-Driven:** [`default_hub_tutorial_sequence.tres`](../data/hub/default_hub_tutorial_sequence.tres) (10 pasos horarios en sentido de reloj desde el Deck Central hasta el Despegue).

---

## 5. Sandbox Lab & Suites de Prueba

- **Lab interactivo:** `sandbox/workbenches/stela_intro_lab/stela_intro_lab.tscn` (`[9]` en `WorkbenchHub`) para iterar shaders del logo, singularidad, materialización `demat_invert` y los 10 pasos de Mochi sin salir de la escena.
- **Suites de verificación:**
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_stela_identity_and_tutorial" -TimeoutSeconds 35`
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_title_and_hub_navigation" -TimeoutSeconds 25`
  - `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_scene_transition_and_tape_button" -TimeoutSeconds 25`
