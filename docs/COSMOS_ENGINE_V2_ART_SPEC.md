# Cosmos Engine v2 — Art, Shader & Atmosphere Spec

> **Objetivo:** Elevar el Cosmos Engine a la estética **Anime Space-Opera Cinematográfico** (Trigger / Honkai Star Rail / Macross) en coherencia visual total con el rig 2.5D de Valentina v2, logrando atmósfera inmersiva, profundidad espacial real y respuesta lumínica **Muy Dramática / Trigger** sobre piloto, alas y armamento orbital 3D — manteniendo 60 FPS en calidad `0/1/2` y legibilidad limpia para combate danmaku.

---

## Decisiones de Diseño Aprobadas

| Eje | Decisión Aprobada | Implementación Técnica |
|---|---|---|
| **Dirección Artística** | Anime Space-Opera Cinematográfico (Trigger / HSR / Macross) | Trazos pictóricos audaces, paletas vibrantes de alto contraste, cel-shading limpio en terminadores y rims, cero fotorrealismo NASA. |
| **Respuesta Lumínica sobre Valentina** | Muy Dramática / Trigger | Baños solares y de bioma intensos en armadura/pelo/arma 3D, rims brillantes, y eclipses oscuros donde destacan los emisivos (monóculo, alas y núcleo orbital). |
| **Proyección de Planetas y Lunas** | Esfera 3D real desde mapas equirectangulares `2:1` *seamless* | `1024×512` POT por planeta/luna, rotación con inclinación axial, nubes 3D desfasadas, especular oceánico/cristal, luces nocturnas, relieve *bump*, auroras y anillos 2.5D con sombra planetaria real. |
| **Estrellas & Anomalías** | Firma visual única para los 5 arquetipos | Fotosferas estilizadas + disco de acreción/jets polares en `magnetar` + anillo de nebulosa planetaria en `white_dwarf` + flares anamórficos y heliosfera mejorada. |
| **Atmósfera & Parallax** | Stack completo multicapa | Nebulosas pictóricas *seamless* con *dark dust lanes* + 4 landmarks (galaxias/pilares) + cortinas `ParallaxDustMid` (`~0.38`) + motas/velo `CosmosForegroundAtmosphere` (`~1.12`) + estaciones/ruinas mecha con balizas. |
| **Organización de Assets** | `assets/environments/cosmos_v2/` | Compilación offline en `tools/cosmos_v2/build_cosmos_assets.py`; `parallax_space/` conservado intacto para retrocompatibilidad durante la transición. |

---

## Hoja de Ruta en 3 Hitos

### Hito 1 — Planetas, Lunas y Anillos 2.5D v2
- **Catálogo (9 arquetipos data-driven vía `CosmosPlanetArchetype`):**
  - *Interior:* `planet_01_volcanic_forge` (corteza basáltica + ríos de magma emisivos en noche/eclipse) y `planet_02_arid_canyon` (dunas doradas + cañones terracota + anillos de polvo opcionales).
  - *Habitable:* `planet_03_oceanic_paradise` (especular oceánico cel-stepped + nubes 3D + ciudades costeras nocturnas) y `planet_04_cyber_ecumenopolis` (megaciudades geométricas cian/ámbar emisivas + anillo orbital fino).
  - *Exterior:* `planet_05_gas_giant_storm` (bandas atmosféricas estilizadas + gran vórtice + anillos helados 2.5D inclinados) y `planet_06_cryo_crystal` (hielo facetado + auroras polares animadas + grietas luminosas).
  - *Lunas:* `moon_01_crater` (relieve bump pronunciado), `moon_02_magma` (fisuras incandescentes) y `moon_03_cryo` (superficie glacial cristalina).
- **Empaquetado RGBA `*_maps.png` (`1024×512`):** `R` = nubes, `G` = emisivo nocturno, `B` = máscara especular, `A` = mapa de altura/*bump* (`[16..240]`).
- **Shaders & Builder:** `celestial_body.gdshader` v2 (retrocompatible con `use_spherical_projection = false` en legacy), `planetary_ring.gdshader` (split Z delante/detrás + sombra analítica del planeta sobre el anillo) y `CosmosPlanetVisualBuilder` integrado en `CosmosSolarSystem2D`.

### Hito 2 — Estrellas v2, Nebulosas Pictóricas y Capas Atmosféricas
- **Estrellas (`5` arquetipos diferenciados):** fotosferas estilizadas con convección 3D; `magnetar` con disco de acreción inclinado 2.5D y jets polares relativistas; `white_dwarf` con anillo de nebulosa planetaria; `star_corona.gdshader` + `star_light_field.gdshader` v2 con heliosfera cromática y flares anamórficos escalables por calidad.
- **Nebulosas y Landmarks:** 2 mapas *seamless* anime con filamentos y *dark dust lanes* re-tinteables por bioma (techo `max_bg_luma` estricto para lectura danmaku) + 4 landmarks macro (galaxias espirales y pilares de polvo estilizados).
- **Capas Nuevas:** `ParallaxDustMid` (cortinas de polvo cósmico entre galaxias y sistemas con *silver-lining* solar) y `CosmosForegroundAtmosphere` (motas de velocidad sutiles y velo óptico solar/eclipse delante del plano de vuelo, conmutables según `SettingsManager.space_background_quality`).

### Hito 3 — Estaciones Orbitales, Ruinas/Escombros Anime y Calibración Trigger
- **Estaciones & Chatarra:** 3 estaciones orbitales anime sci-fi + atlas cel-shaded de asteroides y restos mecha con tintado oscuro coherente con el rig de Valentina y balizas emisivas (`space_station_beacon.gdshader` / `debris_cutout.gdshader` v2).
- **Calibración Final:** ajuste fino de los 6 biomas (`biome_01..06`), `default_rig_lighting.tres` y `default_shadow_system.tres` en `valentina_cosmos_lab.tscn` para lograr contraste dramático estilo Trigger manteniendo silueta y piel limpias en eclipse y proximidad solar.
