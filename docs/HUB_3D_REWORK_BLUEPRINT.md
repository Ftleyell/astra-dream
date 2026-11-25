# Blueprint Maestro — Rework Total del Hub 3D (*Estación Astral v4 — Opción A Híbrida ArcSys*)

> **Estado:** **Promovido a Producción ✅ (`scenes/ui/hub/astral_station/astral_station_hub.tscn`, Mandala Octagonal de 9 Islas sobre Cosmos Engine vivo, Despegue Radial 8-Dir Seamless y Santuario Valkiria Astral)**
> **Ubicación Canónica:** Runtime y shaders en `scenes/ui/hub/astral_station/`, configuraciones `.tres` en `data/hub/default_astral_*.tres`, trim-sheets en `assets/environments/astral_station/`, y lab dev `[H]` heredado en `sandbox/hub_art_lab/hub_art_lab.tscn`.
> **Enfoque Técnico:** **Opción A — Diorama 2.5D Híbrido *ArcSys*** (arquitectura 3D limpia vestida con mapas IA `Ink SDF 2×` + *Hero Props* 3D procedurales/GLB de 3 superficies con cel-shading y contorno caligráfico *inverted-hull*).
> **Documentos Relacionados:** [`VALENTINA_3D_WINGS_CREATION_GUIDE.md`](VALENTINA_3D_WINGS_CREATION_GUIDE.md) · [`VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md) · [`VALENTINA_V2_INTEGRATION_MASTER_PLAN.md`](VALENTINA_V2_INTEGRATION_MASTER_PLAN.md) · [`DOMAIN_MAP.md`](DOMAIN_MAP.md) · [`ART_DIRECTION_AND_PIPELINE.md`](ART_DIRECTION_AND_PIPELINE.md)

---

## 1. Visión, Diagnóstico del Flujo Actual y Principios de Diseño

### 1.1 Problema Actual vs. Flujo Unificado Objetivo
Actualmente la entrada a partida sufre un salto brusco entre dos escenas visualmente desconectadas que duplican responsabilidades (selección de piloto, talentos y skins):

```text
FLUJO ACTUAL (Fragmentado / Placeholder)
TitleScreen ─► HubWorld 3D (Kits Kenney, 7 pedestales, talentos, gacha plano)
                  │
                  └── [Corte duro de escena] ─► CharacterSelectUI 2D (vuelve a elegir piloto,
                                                 talentos, skins, banlist, tomos, compañía, vel.)
                                                     │
                                                     └── [Corte duro] ─► MainGame

FLUJO OBJETIVO (Estación Astral v2 — Continuo e Integrado)
TitleScreen ─► HubWorld 3D ("Estación Astral" con cámara fija -42° y zonas temáticas)
                  ├── Cápsula Central      ──► Cambio rápido de piloto de frente (s) + zoom suave
                  ├── Antesala de Loadout  ──► Módulos progresivos (En Calibración ──► Online)
                  ├── Alas Este / Oeste    ──► Invocador Gacha 3D Hype, Récords, Pets, 5 Reliquias
                  └── Anillo Norte (Cosmos)──► Ignición directa (SERAPH_BLOOM + push-in) ─► MainGame
```

### 1.2 Los 4 Principios Rectores
1. **Regla de los 3 Segundos (Ritmo Roguelite):** un jugador que vuelve de una run o que simplemente quiere jugar entra al Hub, vuela en línea recta hacia el **Anillo de Ignición Norte** y salta al Cosmos sin pantallas intermedias ni fricción.
2. **Revelación Progresiva (*En Calibración* → *Online*):** en la Run 1 el jugador no ve un muro de botones ni mecánicas incomprensibles. Cada estación de preparación existe físicamente en estado **`CALIBRATING`** (mostrando su pista de desbloqueo) y despierta progresivamente al cumplir hitos reales de [`MetaProgressionState`](../core/systems/persistence/meta_progression_state.gd).
3. **Cero Duplicidad y Reutilización Total de Lógica:** cada sistema tiene un único punto de acceso diegético en el Hub, consumiendo directamente los sistemas ya probados en producción:
   - Avatar vivo y shader skins: [`HubRigAvatar3D`](../scenes/ui/hub/components/hub_rig_avatar_3d.gd), [`CosmeticsManager`](../core/systems/cosmetics_manager.gd) y [`CosmeticCarouselModal`](../scenes/ui/cosmetics/cosmetic_carousel_modal.gd).
   - Modales tácticos y meta-progresión: [`CharacterSkillTreeModal`](../scenes/ui/hub/character_skill_tree_modal.gd), [`ArsenalBanlistModal`](../scenes/ui/character_select/arsenal_banlist_modal.gd), [`TomeSelectionModal`](../scenes/ui/character_select/tome_selection_modal.gd), [`PetSelectionModal`](../scenes/ui/character_select/pet_selection_modal.gd), [`NavigatorSelectionModal`](../scenes/ui/character_select/navigator_selection_modal.gd), [`TrophyDetailsModal`](../scenes/ui/hub/trophy_details_modal.gd) y [`HighscoresModal`](../scenes/ui/highscores/highscores_modal.gd).
   - Motor probabilístico y transición a combate: [`GachaBannerEngine`](../scenes/ui/gacha/components/gacha_banner_engine.gd), [`CharacterSelectLaunchController`](../scenes/ui/character_select/components/character_select_launch_controller.gd) y [`SaveManager`](../core/autoloads/save_manager.gd).
4. **Rol Futuro de `Live Banner 2.5D`:** al eliminarse el paso obligatorio por [`character_select.tscn`](../scenes/ui/character_select/character_select.tscn), el *Live Banner 2.5D* queda liberado para momentos de alto impacto emocional sin estorbar el ritmo: pantallas de desbloqueo de nuevas pilotos, ficha de dossier/lore opcional en la Cápsula Central y pantalla de Victoria / MVP post-run.

---

## 2. Plano Arquitectónico y Zonificación Temática (~24×22 m)

La nueva cubierta reemplaza el corredor heredado de `~53 m` por una **estación orbital compacta con cierre arquitectónico en "U" abierta al Sur (`X ∈ [-12, 12]`, `Z ∈ [-10.5, 11.5]`)**, diseñada específicamente para la cámara fija 2.5D Diorama (`FOV = 38°`, `pitch = -42°`), con ventanal Norte abierto al Cosmos, muros temáticos medios en Este/Oeste y barandal bajo (`0.55 m`) en Sur (`+Z`) con **cero oclusores**, manteniendo todo el recorrido a **2–3 segundos de vuelo Zero-G**.

```text
                       🌌 HORIZONTE ABIERTO AL COSMOS 🌌
                 ═════════════════════════════════════════════
                            ╭─────────────────────╮
                            │ ANILLO DE IGNICIÓN  │  Z ≈ -9.5 · Siempre ONLINE
                            │  (Salto al Cosmos)  │  [E] Despegar / Continuar Run
                            ╰──────────▲──────────╯
                                       │
       ┌───────────────────────────────┴───────────────────────────────┐
       │             ANTESALA DE LOADOUT (Z ∈ [-1.0, -6.5])            │
       │                                                               │
       │  [IZQ. 1 · Z=-2.4] Espejo de Skins (Traje/Alas/Arma)          │
       │  [IZQ. 2 · Z=-5.2] Nexo de Talentos (Biomasa/Árbol)           │
       │  [DER. 1 · Z=-2.4] Proyector de Compañía (Pet/Nav)            │
       │  [DER. 2 · Z=-5.2] Consola Táctica (Banlist/Tomos/Vel/Seed)   │
       └───────────────────────────────▲───────────────────────────────┘
                                       │
  ┌─────────────────────┐   ╭──────────┴──────────╮   ┌──────────────────────┐
  │ ALA OESTE           │   │   CÁPSULA CENTRAL   │   │ ALA ESTE             │
  │ Santuario Oscuro    │   │     (0, 0, +2.0)    │   │ Psycho-Pop Neón      │
  │ (X ∈ [-12.0, -6.0]) ├───┤ • Spawn del jugador ├───┤ (X ∈ [+6.0, +12.0])  │
  │                     │   │ • Pose frontal (s)  │   │                      │
  │ • Arco Ceremonial   │   │ • Zoom cámara       │   │ • Invocador Gacha    │
  │   de 5 Reliquias 3D │   │ • Solo Cambio de    │   │   Giroscópico 3D     │
  │ • Materia Oscura    │   │   Piloto            │   │ • Tótem Telemetría   │
  └─────────────────────┘   ╰─────────────────────╯   │ • Lounge Mascotas    │
                                                      └──────────────────────┘
```

### Especificación Detallada de las 5 Zonas

| Zona / Coordenadas | Paleta Temática (Shaders *ArcSys* + `Ink SDF 2×`) | Función y Experiencia In-Game |
|---|---|---|
| **1. Cápsula Central** `(0, 0, +2.0)` | Base **Estación Astral Limpia**: cerámica blanco-plata `#E4ECF5`, chasis azul noche `#141828`, canales HDR que adoptan el color acento de la piloto activa. | **Spawn del Hub** y estación exclusiva de **Cambio de Piloto**. Al interactuar (`[E]`), la piloto se alinea automáticamente mirando de frente (`"s"` — luciendo Face Live, ojos Amatista y cabello 3-zonas), la cámara ejecuta un zoom frontal-lateral suave y despliega el selector de pilotos desbloqueadas. Al cambiar de piloto, un destello de sincronización (`~0.3 s`) reemplaza el avatar y transiciona los acentos HDR del Centro y Antesala al nuevo color acento. |
| **2. Antesala de Loadout** (`Z ∈ [-1.0, -6.5]`) | Mismo lenguaje Astral limpio, dividida simétricamente en flanco **Izquierdo (Piloto)** y **Derecho (Táctica)**. | Pasillo previo al salto espacial con **4 estaciones físicas** que alternan entre `CALIBRATING` y `ONLINE`:<br>• **Izq. 1 — Espejo de Skins:** slots `pilot` / `wings` / `weapon` con preview vivo sobre la piloto (enciende temporalmente Alas 3D y Arma Orbital 3D durante el encuadre).<br>• **Izq. 2 — Nexo de Talentos:** abre [`CharacterSkillTreeModal`](../scenes/ui/hub/character_skill_tree_modal.gd).<br>• **Der. 1 — Proyector de Compañía:** selección de Mascota (te sigue en tiempo real por el Hub) y Navegadora (proyección holográfica en la consola).<br>• **Der. 2 — Consola Táctica de Run:** abre [`ArsenalBanlistModal`](../scenes/ui/character_select/arsenal_banlist_modal.gd), [`TomeSelectionModal`](../scenes/ui/character_select/tome_selection_modal.gd), selector de velocidad (`1.0× / 1.25× / 1.5×`) y **Coordenadas / Seed** (`tactical_seed`). |
| **3. Anillo de Ignición Orbital** `(0, 0, -9.5)` | Borde Norte panorámico abierto al vacío espacial con barandal bajo de cristal energético y anillo cenital luminoso en el piso. | **Siempre ONLINE desde Run 1.** Prompt `[E] SALTAR AL COSMOS` (si `SaveManager.has_active_run()`, muestra modal mínimo `Continuar — Oleada X` / `Nueva Run`).<br>**Ritual de Ignición (`~1.1 s`):** centrado Zero-G mirando al espacio, sobrecarga HDR del anillo en el suelo, despliegue de Alas 3D (`AstralWings3DController.AnimState.SERAPH_BLOOM`) + Anillo Orbital 3D, *push-in* de cámara hacia el horizonte cósmico y commit completo de loadout + `next_run_seed` (`RunLaunchRequest`) vía [`CharacterSelectLaunchController`](../scenes/ui/character_select/components/character_select_launch_controller.gd) + `SceneTransition` → [`main_game.tscn`](../scenes/combat/main_game.tscn), de modo que el horizonte previsualizado desde el Hub coincida exactamente con el sector inicial del Cosmos. |
| **4. Ala Este — Psycho-Pop Neón** (`X ∈ [+6.0, +12.0]`) | Arquitectura oscura de alto contraste `#0D0E1A` + acentos *Psycho-Pop* magenta `#FF1493`, cian `#00F0FF` y oro HDR `#FFD54F`. | **Centro recreativo y cosmético:**<br>• **Invocador Giroscópico Astral 3D (Gacha):** estructura estrella con coreografía cinematográfica in-world (ver Sección 5).<br>• **Tótem de Telemetría:** monolito con pantalla holográfica `Ink SDF 2×` que abre [`HighscoresModal`](../scenes/ui/highscores/highscores_modal.gd).<br>• **Lounge Antigravedad de Mascotas:** discos/cojines flotantes donde las mascotas desbloqueadas no equipadas pasean y descansan sin obstruir la plaza central. |
| **5. Ala Oeste — Santuario Ceremonial Oscuro** (`X ∈ [-12.0, -6.0]`) | Pizarra índigo ceremonial `#101324` + energía púrpura de Materia Oscura `#BF00FF` + iluminación tenue focalizada. | **Arco Ceremonial de 5 Reliquias Cristalinas 3D** (`trophy_boss_aegis`, `trophy_biosphere_core`, `trophy_cryo_core`, `trophy_volcanic_core`, `trophy_monolith_master`). Cada artefacto usa facetas 3D *ArcSys* cuya geometría secundaria, anillos orbitales y emisión HDR escalan según `SaveManager.get_trophy_mastery(...)`; `[E]` enfoca la reliquia y abre [`TrophyDetailsModal`](../scenes/ui/hub/trophy_details_modal.gd). |

---

## 3. Sistema de Progresión Data-Driven (`HubProgressionConfig`)

Cumpliendo la **Regla 3** (cero umbrales numéricos o reglas hardcodeadas en GDScript) y la **Regla 4** (tipado estricto en GDScript 4), todo el desbloqueo progresivo de la Antesala residirá en un recurso `.tres` (`data/hub/default_hub_progression_config.tres`) evaluado por un evaluador puro contra [`SaveManager`](../core/autoloads/save_manager.gd) / [`MetaProgressionState`](../core/systems/persistence/meta_progression_state.gd).

### 3.1 Esquemas Propuestos (`scenes/ui/hub/resources/`)

```gdscript
# hub_module_unlock_rule.gd
class_name HubModuleUnlockRule
extends Resource

enum UnlockMetric {
	ALWAYS_ONLINE = 0,
	PLAYABLE_PILOTS_AT_LEAST = 1,
	UNLOCKED_SKINS_AT_LEAST = 2,
	BIOMASS_OR_ANTIMATTER_OR_RUNS = 3,
	UNLOCKED_COMPANIONS_AT_LEAST = 4,
	TOTAL_RUNS_PLAYED_AT_LEAST = 5,
	TOTAL_BOSSES_KILLED_AT_LEAST = 6,
	TOTAL_RUNS_CLEARED_AT_LEAST = 7,
}

@export var module_id: StringName = &""
@export var display_name: String = ""
@export var unlock_metric: UnlockMetric = UnlockMetric.ALWAYS_ONLINE
@export var threshold: int = 1
@export var locked_hint_text: String = "En Calibración"
@export var accent_override: Color = Color(0.0, 0.94, 1.0, 1.0)
```

```gdscript
# hub_progression_config.gd
class_name HubProgressionConfig
extends Resource

@export var module_rules: Array[HubModuleUnlockRule] = []
@export var calibrating_desaturation: float = 0.85
@export var calibrating_tint: Color = Color(0.32, 0.36, 0.48, 1.0)
@export var newly_unlocked_pulse_hz: float = 2.2
@export var debug_unlock_all_in_debug_mode: bool = true

# Política configurable en .tres para ajustar reglas de integridad al implementar RNG seeded completo en runs
@export_group("Seeded Run Policy")
@export var allow_highscores_on_custom_seed: bool = false
@export var allow_trophies_on_custom_seed: bool = false
```

### 3.2 Tabla de Módulos y Fuentes Reales en Persistencia

| `module_id` | Estación / Sub-módulo | Estado Inicial (Run 1) | Métrica Real (`SaveManager` / `MetaProgressionState`) | Texto Visible en `CALIBRATING` (Ejemplo) |
|---|---|---|---|---|
| `ignition_ring` | Anillo de Ignición Norte | **ONLINE** | `ALWAYS_ONLINE` | — *(Disponible desde el primer segundo)* |
| `pilot_capsule` | Cápsula Central de Piloto | **ONLINE** | `ALWAYS_ONLINE` *(permite cambio si `>= 2` pilotos tienen `is_playable_rework_ready` + `is_character_unlocked`)* | *"Nuevas pilotos en sincronización"* *(si solo hay 1 lista)* |
| `skins_mirror` | Espejo de Skins (`pilot/wings/weapon`) | `CALIBRATING` | `UNLOCKED_SKINS_AT_LEAST >= 1` (`SaveManager.get_unlocked_skins().size()`) | *"Consigue tu primera skin en el Invocador Gacha"* |
| `talents_nexus` | Nexo de Talentos | `CALIBRATING` | `BIOMASS_OR_ANTIMATTER_OR_RUNS` (`get_biomass() > 0 or get_antimatter() > 0 or total_runs_played >= 1`) | *"Recolecta Biomasa o completa tu 1.ª incursión"* |
| `companions_projector` | Proyector de Compañía (`Pet` + `Navigator`) | `CALIBRATING` | `UNLOCKED_COMPANIONS_AT_LEAST >= 1` (`get_unlocked_pets().size() > 0 or get_unlocked_navigators().size() > 0`) | *"Desbloquea una Mascota o Navegante"* |
| `tactical_banlist` | Sub-módulo Consola Táctica: Banlist | `CALIBRATING` | `TOTAL_RUNS_PLAYED_AT_LEAST >= 1` (`career_stats["total_runs_played"]`) | *"Completa 1 incursión para calibrar Banlist"* |
| `tactical_tomes` | Sub-módulo Consola Táctica: Pool de Tomos | `CALIBRATING` | `TOTAL_BOSSES_KILLED_AT_LEAST >= 1` (`career_stats["total_bosses_killed"]`) | *"Derrota 1 Jefe para calibrar Tomos"* |
| `tactical_speed` | Sub-módulo Consola Táctica: Velocidad (`1.25×/1.5×`) | `CALIBRATING` | `TOTAL_RUNS_CLEARED_AT_LEAST >= 1` (`career_stats["total_runs_cleared"]`, ajustable en `.tres`) | *"Supera un sector completo para desbloquear Overclock"* |
| `tactical_seed` | Sub-módulo Consola Táctica: Coordenadas / Seed | `CALIBRATING` | `TOTAL_RUNS_PLAYED_AT_LEAST >= 1` (`career_stats["total_runs_played"]`, ajustable en `.tres`) | *"Completa 1 incursión para calibrar Coordenadas de Salto"* |

### 3.3 Contrato Visual de los 3 Estados + Override de Depuración
1. **`CALIBRATING`:** chasis apagado (`calibration_factor = 1.0` en shader *ArcSys*), sin holograma flotante activo, LED ámbar tenue y prompt pasivo al acercarse mostrando `locked_hint_text` (sin abrir modal pesado ni bloquear el paso).
2. **`NEWLY_UNLOCKED`:** cuando una condición pasa de bloqueada a desbloqueada respecto al último estado visto en sesión/perfil, la estación emite un pulso HDR rítmico (`newly_unlocked_pulse_hz`) y muestra el indicador **`ONLINE · NUEVO`** hasta la primera interacción del jugador.
3. **`ONLINE`:** canales HDR al `100%` en el color acento correspondiente, holograma 3D/IA encendido y prompt `[E]` activo. En el caso de la **Consola Táctica**, si al menos 1 sub-módulo está `ONLINE`, se abre su panel mostrando en vivo los sub-módulos desbloqueados y los restantes con su candado + pista.
4. **Override en [`DebugManager`](../core/autoloads/debug_manager.gd):** cuando `DebugManager.is_debug_enabled()` e `is_enabled` estén activos (o mediante toggle de desarrollador en Hub cuando `debug_unlock_all_in_debug_mode == true`), el evaluador puede forzar todos los módulos a `ONLINE` para pruebas instantáneas sin alterar el archivo guardado del jugador.

---

## 4. Máquina de Estados de Cámara (`HubCameraController3D` v2)

El controlador actual ([`hub_camera_controller_3d.gd`](../scenes/ui/hub/components/hub_camera_controller_3d.gd)) fija la cámara usando [`HubDioramaConfig`](../scenes/ui/hub/resources/hub_diorama_config.gd) (`camera_fov = 38.0`, `camera_pitch_deg = -42.0`, `camera_offset = Vector3(0, 9.2, 10.2)`). Se extenderá a una máquina de estados data-driven (`HubCameraPreset` en `.tres`) con interpolación exponencial suave (`~0.35–0.45 s`), manteniendo intacta la vista Diorama por defecto en `FREE_ROAM`:

| Estado de Cámara | Cuándo se Activa | Comportamiento de Encuadre |
|---|---|---|
| **`FREE_ROAM`** | Vuelo libre por la Estación Astral (estado base). | Conserva el encuadre canónico **`FOV 38°`, `pitch -42°`** siguiendo al jugador dentro de los límites compactos (`~24×22 m`). |
| **`CAPSULE_PILOT_FOCUS`** | Al interactuar `[E]` en la Cápsula Central. | La piloto se centra en `(0, 0, 2.0)` mirando de frente (`"s"`); la cámara baja el pitch (`~ -16°` a `-22°`) y reduce `FOV` (`~30°`) encuadrando a la piloto en un tercio de pantalla (luciendo Face Live) y dejando el lado opuesto limpio para el carrusel de pilotos. |
| **`SKINS_MIRROR_FOCUS`** | Al abrir el Espejo de Skins en Antesala. | Encuadre 3/4 cercano hacia la piloto con **Alas 3D + Arma Orbital 3D encendidas temporalmente** para visualizar en tiempo real los cambios de [`CosmeticsManager`](../core/systems/cosmetics_manager.gd) (`pilot`, `wings`, `weapon`). |
| **`STATION_FOCUS`** | Al abrir Talentos, Compañía o Consola Táctica. | Desplazamiento lateral suave hacia la consola correspondiente + leve desenfoque/dimming de UI lateral sin sacar al jugador del mundo 3D. |
| **`GACHA_SUMMON_CINEMATIC`** | Durante tiradas en el Invocador Giroscópico (Ala Este). | Encuadre dramático frontal-bajo hacia los 3 anillos mecha y el núcleo cristalino, con *camera shake* controlado y ocultamiento temporal del HUD del Hub. |
| **`TROPHY_FOCUS`** | Al inspeccionar cualquiera de las 5 Reliquias (Ala Oeste). | Paneo puntual hacia el pedestal ceremonial seleccionado mientras se abre [`TrophyDetailsModal`](../scenes/ui/hub/trophy_details_modal.gd). |
| **`IGNITION_LAUNCH`** | Al confirmar `[E] SALTAR AL COSMOS` en el Anillo Norte. | Encuadre heroico detrás/diagonal del anillo mirando al horizonte espacial durante la secuencia de `~1.1 s`, culminando en *push-in* hacia el Cosmos y transición a [`main_game.tscn`](../scenes/combat/main_game.tscn). |

---

## 5. Especificación del Invocador Giroscópico Astral 3D (Gacha Hype)

Reemplaza la cúpula 2D plana actual por una estructura protagonista en el **Ala Este (`Psycho-Pop Neón`)** construida con la misma técnica 3D *ArcSys* de [`AstralWings3DMeshBuilder`](../scenes/pilots/vfx/astral_wings_3d_mesh_builder.gd) y [`RailLance3DMeshBuilder`](../scenes/pilots/weapons/rail_lance_3d_mesh_builder.gd).

### 5.1 Anatomía 3D *ArcSys* (3 Superficies + Contorno Caligráfico)
1. **Base Octogonal *Psycho-Pop*:** pedestal con biseles duros, cunas oscuras (`SURFACE_CHASSIS`), placas blanco-titanio (`SURFACE_ARMOR`) y canaletas luminosas (`SURFACE_CRYSTAL`) que pulsan al ritmo del banner activo.
2. **3 Anillos Mecha Giroscópicos Concéntricos:**
   - Aro Exterior (lento, contrarrotativo, aletas estabilizadoras con venas HDR).
   - Aro Medio (eje cruzado inclinado a `±45°`, segmentos blindados con *crease ink*).
   - Aro Interior (anillo de enfoque rápido con cheurones hacia el núcleo).
3. **Núcleo Cristalino Central:** octaedro multifaceta suspendido en el centro exacto de los 3 anillos; al estallar, sus fragmentos superiores/inferiores se separan revelando la cápsula/holograma del premio.

### 5.2 Integración Exacta con `GachaBannerEngine`
El Invocador reutiliza 100% la lógica probabilística y persistencia ya implementadas en [`gacha_banner_engine.gd`](../scenes/ui/gacha/components/gacha_banner_engine.gd) y [`SaveManager`](../core/autoloads/save_manager.gd) (`get_gacha_tokens()`, `get_banner_pity()`, `resolve_pull(...)`):

| Banner (`GachaBannerEngine.BANNERS_CONFIG`) | Color de Reposo / Carga del Invocador | Reglas Sincronizadas |
|---|---|---|
| `"general"` (*Estelar General*) | Cian `#00F0FF` | `PITY_THRESHOLD = 10` · `DEFAULT_EPIC_RATE = 0.15` |
| `"ships"` (*Hangar de Alas, Naves y Armas*) | Naranja `#FF801A` | Filtra categorías `ship` / `wings` / `weapon` |
| `"pilots"` (*Academia de Pilotos y Trajes*) | Magenta `#FF40B3` | Filtra categorías `pilot` / `navigator` |

- **Tiradas soportadas:** `×1`, `×5` y `×10` (consumiendo fichas vía `SaveManager.spend_gacha_tokens(...)`).
- **Mapeo de rarezas:**
  - `"common"` → Energía **Cian / Plata Estelar** HDR limpia.
  - `"epic"` o `is_pity == true` → Energía **Oro Solar / Carmesí Rubí** HDR intensa (`> 1.35` bajo `AgX` Bloom), con pequeña probabilidad de **Fake-Out** (arranca cargando en Cian común y en el instante previo al impacto rompe el sello hacia Oro/Carmesí con un golpe de cámara y sonido).

### 5.3 Coreografía de 5 Fases (Secuencia de Tirada)
1. **`0.00 s` — Encuadre & Selección:** zoom cinematográfico `GACHA_SUMMON_CINEMATIC`; selector limpio de Banner + botones `×1` / `×5` / `×10` y barra de Pity (`X / 10`).
2. **`0.15 s – 1.15 s` — Carga & Alineación Giroscópica:** los 3 anillos aceleran exponencialmente convergiendo en el mismo plano ecuatorial; chispas estelares convergen hacia el centro y la cámara aplica micro-vibración creciente.
3. **`1.15 s – 1.55 s` — Tensión / Posible *Fake-Out*:** el núcleo queda suspendido al rojo vivo (o cian simulando común antes de fisurarse a oro/carmesí si hay *fake-out* en un resultado `"epic"`).
4. **`1.55 s – 1.95 s` — Apertura en Flor & Estallido `AgX` Bloom:** los 3 anillos se detienen y abren radialmente, flash HDR limpio y proyección del resultado (en `×10`, cascada rápida de cartas/cápsulas con pausa heroica en las épicas).
5. **`1.95 s+` — Reveal & Acción Inmediata:** vista previa viva de la skin obtenida (usando [`ShaderSkinLivePreview`](../scenes/ui/cosmetics/components/shader_skin_live_preview.gd) o el propio avatar si aplica), botón **`Equipar ahora`** (actualiza a la piloto del Hub al cerrar sin pasos extra) y botón **`Saltar`** disponible desde el segundo `0.2`.

---

## 6. Arquitectura de Shaders 3D *ArcSys* y Manifiesto de Assets (Opción A)

### 6.1 Los 2 Shaders Maestros del Hub
Para que la arquitectura y los muebles parezcan dibujados por el mismo estudio que Valentina v2 (`02_valentina_razor_sharp`) sin multiplicar `SubViewport`s:

1. **`hub_arcsys_surface_3d.gdshader`** *(Pisos, Mamparos, Ventanales, Señalética)*
   - **Entradas Multi-Mapa:** `albedo_tex`, `id_mask_tex` (`R` acento HDR reactivo, `G` placa base, `B` chasis oscuro), `ilm_mask_tex` (`R` especular, `G` AO/cel bias, `B` rim, `A` emisivo HDR) y `ink_sdf_tex` (`2×`, filtrado sin mipmaps y muestreado en `textureLod(..., 0.0)` igual que [`VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md)).
   - **Reactividad al Piloto:** interpola los canales `id_mask.R` e `ilm_mask.A` hacia `pilot_accent_color` en el Centro y Antesala.
   - **Iluminación Real Cel-Shaded (`void light()`):** implementa corte cel duro de 2–3 bandas usando `ATTENUATION` de Godot 4 para que las sombras proyectadas por muros, consolas y arcos recorten limpiamente sobre el suelo sin degradados PBR blandos.

2. **`hub_arcsys_prop_3d.gdshader` + `hub_arcsys_outline_3d.gdshader`** *(Props 3D y Reliquias)*
   - Evolución directa de [`astral_wing_toon_3d.gdshader`](../scenes/pilots/shaders/astral_wing_toon_3d.gdshader) y [`astral_wing_outline_3d.gdshader`](../scenes/pilots/shaders/astral_wing_outline_3d.gdshader).
   - **Contrato de Vértice Invariante:** normales planas en `NORMAL` (para cel-shading duro y *crease ink* vía `fwidth(NORMAL)`), normales suaves soldadas en `UV.xy` / `UV2.x` para contorno *inverted-hull* sin grietas, y progreso/altura normalizada en `UV2.y` para flujos HDR.
   - **Estado de Progresión (`calibration_factor`):** parámetro `[0.0 .. 1.0]` que desatura placas, apaga emisiones HDR y tiñe hacia ámbar/pizarra cuando una estación está `CALIBRATING`.
   - **Contorno Compensado por Distancia (`hub_arcsys_outline_3d.gdshader`):** a diferencia de las alas/armas (que están siempre a distancia fija de cámara en un `SubViewport`), un prop en el Hub cambia de profundidad al hacer zoom o caminar. El *vertex shader* debe proyectar la normal suave a *clip-space* (`PROJECTION_MATRIX * MODELVIEW_MATRIX`) y escalar el desplazamiento proporcionalmente a `CLIP_POSITION.w` (sujeto a `clamp` min/max) para mantener un grosor caligráfico uniforme en pantalla con `FOV 38°`.

### 6.2 Presupuesto GPU de `SubViewport`s
- **Entorno y todos los props del Hub:** **0 `SubViewport`s adicionales** (se renderizan nativamente en la escena 3D principal con el pipeline *mobile* + `AgX` Bloom).
- **Ventanal Norte (`CosmosRootNode` vivo):** utiliza **1 `SubViewport` 2D HDR dedicado** cuya resolución escala automáticamente con `SettingsManager.space_background_quality` (`0 → 640×320`, `1 → 960×480`, `2 → 1280×640`), con `FloatingOrigin` desactivado y suspensión automática (`UPDATE_DISABLED`) si no es visible.
- **Avatar del jugador (`HubRigAvatar3D`):** conserva su único `SubViewport` (`512×512`, `MSAA_4X`, `use_hdr_2d`).
- **Alas 3D y Arma Orbital 3D:** permanecen apagadas durante `FREE_ROAM` para máxima limpieza visual y mínimo gasto; se activan únicamente de forma focal durante `SKINS_MIRROR_FOCUS` y el ritual `IGNITION_LAUNCH`.

### 6.3 Manifiesto Acotado de Assets (Cero Dependencia de Kenney)

| Tipo | Cantidad | Activo | Técnica / Origen |
|---|---|---|---|
| **Sets de Texturas IA (`Ink SDF 2×`)** | **4 sets** | 1. Piso Cerámico Astral modular (`1:1` seamless)<br>2. Paneles de Pared / Mamparo (Astral, Psycho-Pop, Santuario)<br>3. Anillo de Ignición Orbital Norte (`1:1` cenital)<br>4. Atlas de Pantallas Holográficas & Señalética (`16:9`) | Prompts Sección 7 → compilador Python [`tools/build_hub_surface_maps.py`](../tools/build_hub_surface_maps.py) *(reutilizando la base de [`build_valentina_weapon.py`](../sandbox/pilot_rig_lab/tools/build_valentina_weapon.py))* + [`build_orbital_ring_texture.py`](../sandbox/pilot_rig_lab/tools/build_orbital_ring_texture.py) para el anillo. |
| **Familias de Mallas 3D *ArcSys*** | **6 familias** | 1. **Cápsula Central** (plataforma octogonal + semiarco trasero + halo)<br>2. **Consola Modular de Antesala** (1 chasis reutilizado en 4 estaciones con prisma holográfico)<br>3. **Invocador Giroscópico Gacha 3D** (base + 3 aros + núcleo)<br>4. **Tótem de Telemetría + Pads de Mascotas** (Ala Este)<br>5. **5 Reliquias Cristalinas de Jefes** (Ala Oeste)<br>6. **Costillas Estructurales, Marco Norte & Barandal Sur** | **100% Procedural GDScript (`ArrayMesh`)** mediante la librería compartida `HubArcSysMeshPrimitives` (contrato de 3 superficies, *winding* horario Godot 4 y normales suaves soldadas en `UV`/`UV2`, cero `.glb` externos). |

---

## 7. Plantillas de Prompts IA para los Assets Base (Opción A)

Todas las imágenes fuente deben respetar el estándar de [`VALENTINA_ORBITAL_WEAPON_SPEC.md`](VALENTINA_ORBITAL_WEAPON_SPEC.md): **cero glow/bloom horneado**, **cero sombras proyectadas de ambiente**, **tinta cerrada `#121622`** y **separación cromática estricta** para extracción automática de `id_mask`, `ilm_mask` e `ink_sdf 2×`.

### Prompt 1 — Piso Cerámico Astral Modular (`1:1` Top-Down Seamless)
*Destino propuesto: `sandbox/hub_art_lab/source_refs/hub_floor_tile_master.png`*

```text
Generate a seamless tileable 1:1 top-down orthographic 2D sci-fi floor texture for an anime space observatory deck, in ultra-crisp Arc System Works / Guilty Gear Strive cel-shaded game art style.

DESIGN & LAYOUT:
- Clean architectural deck plating with geometric chamfered panel seams, subtle recessed maintenance channels, and crisp tactical alignment lines that tile seamlessly on all four edges (top-to-bottom and left-to-right).
- Strictly orthographic 90-degree top-down flat projection (ZERO perspective distortion, ZERO vanishing point).
- Crisp dark ink panel linework (#121622) separating every armor slab cleanly.
- ZERO text, ZERO letters, ZERO numbers, ZERO grime, ZERO rust, ZERO baked drop shadows, ZERO soft glow bloom halos.

STRICT 3-MATERIAL FLAT CEL-SHADED COLOR SEPARATION (for automated ID mask extraction):
1) Main ceramic-metallic deck plates: cool clean silver-white (#E4ECF5 to #F4F8FF, subtle chamfer bevels in #B8C7DC).
2) Recessed mechanical under-channels & seam frames: deep dark navy-slate (#1D273B to #2B3954).
3) Reactive energy trim strips (thin geometric inlaid channels): pure flat saturated crimson-ruby (#E01E48 to #FF2A55) with razor-sharp opaque edges and ZERO halo bleed.
```

### Prompt 2 — Paneles Modulares de Pared / Mamparo (`16:9` Ortográfico Frontal)
*Variar el bloque `[VARIANT]` según zona: **(A) Astral Limpia**, **(B) Psycho-Pop Este**, **(C) Santuario Oeste***

```text
Generate a clean front-orthographic 16:9 modular sci-fi wall bulkhead panel sheet for an anime space station interior, in ultra-crisp Arc System Works / Guilty Gear Strive cel-shaded game art style.

DESIGN & LAYOUT:
- Strictly flat front-facing orthographic elevation (ZERO perspective tilt, ZERO floor plane).
- Cleanly divided modular architectural bays: reinforced angled structural ribs, geometric maintenance hatches, recessed conduit vents, and [VARIANT: (A) clean panoramic observatory frames with silver-white ceramic armor / (B) dark high-contrast cyberpunk arcade housing with angular neon conduit frames / (C) tall solemn octagonal relic alcove pillars with deep indigo slate stone-metal].
- Razor-sharp closed dark ink outlines (#121622) and crisp geometric panel seams.
- ZERO text, ZERO baked shadows, ZERO soft airbrushing, ZERO ambient fog or glow bleed.

STRICT 3-MATERIAL CEL-SHADED COLOR SEPARATION:
1) Primary wall armor plating: [VARIANT: (A) #E4ECF5 silver-white / (B) #22263D dark cyber-slate / (C) #2A2F4D ceremonial slate] with crisp flat cel bevels.
2) Deep recessed chassis ribs & mechanical backing: deep ink-navy (#121622 to #1D273B).
3) Thin inlaid energy conduit lines: pure opaque saturated crimson-ruby (#FF2A55) [or #FF1493 for Psycho-Pop / #BF00FF for Sanctuary] with crisp hard edges and ZERO bloom halo.
```

### Prompt 3 — Anillo de Ignición Orbital Norte (`1:1` sobre `#000000` — Compatible con `build_orbital_ring_texture.py`)
*Compilar directamente con [`sandbox/pilot_rig_lab/tools/build_orbital_ring_texture.py`](../sandbox/pilot_rig_lab/tools/build_orbital_ring_texture.py)*

```text
Generate a single clean 1:1 square 2D game-VFX production texture of a top-down orthographic circular orbital launch/ignition pad ring for an anime space hangar, strictly on a completely pure pitch-black (#000000) background.

CRITICAL PRODUCTION CONSTRAINTS:
- Strictly 1:1 square aspect ratio, perfectly centered at exact image center (50%, 50%), outer ring diameter occupying ~86% of image width/height.
- COMPLETELY EMPTY PITCH-BLACK HOLLOW CENTER (inner open diameter ~54% of image width — ZERO elements inside the center so the pilot stands cleanly inside).
- Pure flat 2D top-down orthographic view (perfect mathematical circle, NOT tilted or oval).
- ZERO text, ZERO letters, ZERO numbers, ZERO labels, ZERO grid lines, ZERO vignette, ZERO soft glow haze bleeding onto #000000.
- Clean empty black radial gap separating an inner precision astrolabe micro-tick ring from an outer heavy armored launch ring (allowing independent counter-rotation in shader).
- STRICT 2-COLOR HIGH-CONTRAST SEPARATION:
  1) Structural launch ring segments & precision ticks: razor-sharp crisp white-silver (#E6F0FF to #FFFFFF).
  2) Ignition lock-on chevrons & energy segments: vivid saturated crimson-ruby (#FF1F4B to #FF4068).
```

### Prompt 4 — Atlas de Pantallas Holográficas & Señalética (`16:9` sobre `#000000`)
*Contiene los íconos vectoriales de las estaciones en cuadrícula limpia para recortar por UV en shader.*

```text
Generate a clean 16:9 flat 2D UI/hologram icon atlas grid on a completely pure pitch-black (#000000) background, in crisp Japanese anime mecha tactical HUD style (Studio Trigger / Arc System Works).

GRID LAYOUT (4x2 evenly spaced clean icon cells with generous black margin around each icon, ZERO grid border lines, ZERO labels, ZERO text):
- Cell 1 (Top-Left): Stylized geometric pilot helmet/wing silhouette emblem (Skins Mirror).
- Cell 2 (Top-Mid-Left): Interconnected orbital constellation / star-node tree emblem (Talents Nexus).
- Cell 3 (Top-Mid-Right): Dual companion drone + wing emblem (Companions Projector).
- Cell 4 (Top-Right): Crossed target reticle & ban-shield tactical emblem (Tactical Console).
- Cell 5 (Bottom-Left): High-voltage triangular gacha prism & orbiting rings emblem (Gacha Summoner).
- Cell 6 (Bottom-Mid-Left): Crowned orbital telemetry podium bars emblem (Highscores Totem).
- Cell 7 (Bottom-Mid-Right): Geometric lock & rotating calibration chevron emblem (Calibrating / Locked State).
- Cell 8 (Bottom-Right): Upward hyper-launch chevron wing emblem (Orbital Ignition).

CRITICAL CONSTRAINTS:
- Crisp hard vector-like silhouettes using ONLY pure white-cyan (#E8FFFF) and vivid crimson/magenta accent (#FF2A6D) on pure #000000 black.
- ZERO text, ZERO letters, ZERO numbers, ZERO blurry glow halos, ZERO background gradients.
```

---

## 8. Semillas Deterministas (`RunLaunchRequest`), Coordenadas de Salto y Sincronía con Cosmos Engine

Para garantizar desde la base que tanto **Cosmos Engine** (activo hoy mediante [`main_game.gd`](../scenes/combat/main_game.gd) → [`CosmosCombatEnvironment`](../scenes/combat/environment/cosmos_combat_environment.gd) → [`CosmosRootNode`](../scenes/combat/environment/cosmos/scenes/cosmos_root.gd)) como las futuras **runs 100% *seeded*** compartan un único origen limpio sin tener que refactorizar el Hub en el futuro, la semilla nace en la Estación Astral antes del salto.

### 8.1 Value Object `RunLaunchRequest` (1 Semilla Maestra → Sub-Streams Aislados)
En lugar de usar una única secuencia global `randi()` (vulnerable a desincronizaciones si cambia el orden de disparos, enemigos o cofres), el lanzamiento genera un Value Object ligero (`RunLaunchRequest` en memoria/transición) con:
- **`master_seed: int`:** entero positivo de 31 bits (`1 .. 0x7FFFFFFF`), con representación legible y compartible como código de coordenada estelar (ej. `ASTR-7F3K9`) con conversión biyectiva `code ↔ int`.
- **`seed_mode: SeedMode`:**
  - `AUTO` (por defecto en cada nueva incursión).
  - `CUSTOM` (introducida o repetida por el jugador).
  - `DAILY` (reservado para futura coordenada diaria determinista por fecha UTC).
- **Sub-semillas derivadas por dominio (sin contaminación cruzada entre RNGs):** aplicando hashing determinista con *salt* distinto por subsistema (vía [`CosmosHasher`](../scenes/combat/environment/cosmos/core/cosmic_hasher.gd) e instancias `RandomNumberGenerator` dedicadas):
  1. `cosmos_seed`: **activo hoy**; alimenta `main_game.run_seed` y `CosmosRootNode.set_run_seed(...)` (estrellas, sectores no estelares, órbitas, corredores y muestreo lumínico).
  2. `run_director_seed`: **contrato preparado** para oleadas, satélites, jefes y eventos de tiempo.
  3. `run_loot_seed`: **contrato preparado** para ofertas de Level-Up, tiendas satelitales, Arcanas y Bifurcaciones (*Run Forks*).
- **Integración con el lanzamiento:** [`CharacterSelectLaunchController`](../scenes/ui/character_select/components/character_select_launch_controller.gd)`.commit_launch(...)` registra la solicitud pendiente para que [`main_game.gd`](../scenes/combat/main_game.gd) consuma la `master_seed` antes de su fallback `if run_seed == 0:`.

### 8.2 UX en el Hub 3D (Sub-módulo `tactical_seed`)
- **En Run 1 y modo `AUTO` (Cero Fricción):** al entrar al Hub o volver de una incursión, se pre-genera silenciosamente una nueva `next_run_seed` aleatoria. El jugador puede ignorar la Consola Táctica y saltar al Cosmos desde el Anillo Norte sin ver menús técnicos.
- **Cuando `tactical_seed` pasa a `ONLINE`:** la Consola Táctica (Derecha 2) ofrece 3 controles claros:
  1. Toggle **`AUTO` / `CUSTOM`** (y futuro selector `DAILY`).
  2. Campo para **ingresar o pegar código de coordenada** (`ASTR-XXXXX` o entero).
  3. Botón de 1 clic **`Repetir última coordenada`** para revancha inmediata tras una run memorable.
- **Trazabilidad en Partida y Post-Run:** mostrar el código de coordenada discretamente en el menú de pausa y en [`GameOverModal`](../scenes/ui/game_over/game_over_modal.gd) con acción rápida para copiarlo al portapapeles.

### 8.3 Sincronía Visual con el Horizonte Norte
- Como la Estación Astral conoce `next_run_seed` antes del lanzamiento, el Ventanal Panorámico Norte proyecta un **`CosmosRootNode` real en vivo** dentro de un `SubViewport` dedicado (`HubCosmosWindowController`), ejecutando `cosmos_root.set_run_seed(next_run_seed)` para mostrar exactamente el sistema estelar, planetas, corredores y paleta inicial de la celda `(0, 0)` ([`CosmosMacroGrid`](../scenes/combat/environment/cosmos/core/cosmic_macro_grid.gd)).
- Al confirmar o modificar una semilla manual en la Consola Táctica, el ventanal Norte ejecuta un **pulso de re-sintonización (`retune_flash ~0.3 s`)** y actualiza el universo en vivo, uniendo visualmente lo que el jugador contempla desde el Hub con el sector exacto donde aparecerá en combate.

### 8.4 Reglas de Integridad Configurables en `.tres`
- Toda partida lanzada con `seed_mode == CUSTOM` recibe internamente la etiqueta/badge **`[SEEDED]`**.
- Las restricciones competitivas y de progresión **no se hardcodean** en GDScript: se consultan directamente en [`HubProgressionConfig`](#31-esquemas-propuestos-scenesuihubresources) (`allow_highscores_on_custom_seed` y `allow_trophies_on_custom_seed`, ambas `false` por defecto) para decidir si una run con semilla manual registra marca en [`HighscoresModal`](../scenes/ui/highscores/highscores_modal.gd) o desbloquea trofeos, permitiendo calibrar la política con precisión cuando se active el RNG *seeded* completo de runs.

---

## 9. Hoja de Ruta Incremental (Fases 1–4) y Verificación

| Fase | Alcance y Entregables Concretos | Criterio de Salida y Test Asociado |
|---|---|---|
| **Fase 1 — *Vertical Slice* en Sandbox** | • Crear `sandbox/hub_art_lab/` (escena aislada del Hub nuevo, cero impacto en producción).<br>• Implementar `hub_arcsys_surface_3d.gdshader`, `hub_arcsys_prop_3d.gdshader` y `hub_arcsys_outline_3d.gdshader` (con compensación de distancia en *clip-space*).<br>• Compilar el primer set IA: piso cerámico (`build_hub_surface_maps.py`) + Anillo de Ignición (`build_orbital_ring_texture.py`).<br>• Construir la **Cápsula Central** (auto-alineación frontal `"s"` + zoom de cámara), **1 Consola de Antesala** (toggle en vivo `CALIBRATING ↔ ONLINE`) y montar a Valentina v2 (`HubRigAvatar3D`). | Se valida visualmente la cohesión 1:1 entre Valentina 2D, el piso `Ink SDF 2×` con sombras reales y los props 3D *ArcSys*.<br>Suite headless: `tests/sandbox/test_hub_art_lab.tscn` (`tools/run_tests.ps1 -Test "hub_art_lab"`). |
| **Fase 2 — Lab Invocador Gacha 3D Hype** | • Crear `sandbox/hub_art_lab/gacha_3d_lab.tscn`.<br>• Construir la malla 3D giroscópica de 3 anillos + núcleo cristalino + secuencia cinematográfica de 5 fases.<br>• Conectar con `GachaBannerEngine` (`general` / `ships` / `pilots`, `×1/×5/×10`, pity y rarezas `common` / `epic` + *fake-out*). | Tiradas reales deterministas/aleatorias funcionando, `Saltar` y `Equipar ahora` verificados.<br>Suite headless: `tests/sandbox/test_gacha_3d_lab.tscn`. |
| **Fase 3 — Estación Astral Completa** | • Ensamblar las 5 zonas en el diorama `~24×22 m`: **Antesala** (4 estaciones + `HubProgressionConfig` `.tres`), **Ala Este** (Invocador + Tótem Récords + Lounge Mascotas), **Ala Oeste** (Arco de 5 Reliquias cristalinas con escalado por maestría) y **Ventanal / Horizonte Cosmos** sincronizado con `next_run_seed`.<br>• Implementar `RunLaunchRequest` (sub-semillas `cosmos_seed` / `run_director_seed` / `run_loot_seed`), sub-módulo `tactical_seed` y el ritual completo de salida (`SERAPH_BLOOM` + Anillo Orbital 3D + push-in hacia el espacio). | Navegación fluida sin colisiones muertas, los 3 estados (`CALIBRATING / NEWLY_UNLOCKED / ONLINE`) responden a `MetaProgressionState`, el horizonte Norte refleja el sector de `next_run_seed` y todas las estaciones abren sus modales sin duplicidad. |
| **Fase 4 — Promoción a Producción & Limpieza** | • Sustituir [`scenes/ui/hub/hub_world.tscn`](../scenes/ui/hub/hub_world.tscn) y sus componentes modulares (`hub_hangar_builder_3d.gd`, `hub_camera_controller_3d.gd`, `pedestal_visual_presenter.gd`, `hub_terminal_manager.gd`, `hub_trophy_room_manager.gd`) por la Estación Astral.<br>• Retirar la redirección obligatoria hacia [`character_select.tscn`](../scenes/ui/character_select/character_select.tscn) al pulsar Desplegar / Ignición, ejecutando el commit de [`CharacterSelectLaunchController`](../scenes/ui/character_select/components/character_select_launch_controller.gd) + `RunLaunchRequest` directo hacia [`main_game.tscn`](../scenes/combat/main_game.tscn).<br>• Migrar `default_hub_diorama_config.tres` + `default_hub_progression_config.tres` a `data/hub/`. | Actualizar y validar `test_hub_25d_valentina_rig` (incluyendo traspaso determinista de `run_seed` y flags de `.tres`) + ejecutar regresión integral final:<br>`powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly`. |
