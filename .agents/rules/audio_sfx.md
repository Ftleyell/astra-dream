---
trigger: model_decision
description: "Reglas de arquitectura, tabla contractual y comandos de test para AudioManager v2, SfxCueBank, armas SFX, Ambience y SfxLab."
---

# Reglas de Audio, SFX y SfxLab — Stela Galactica

> Guía rápida obligatoria para agentes que modifiquen o ajusten efectos de sonido, mezclas, buses, camas atmosféricas o el laboratorio `SfxLab`. Documentación completa en [`docs/SFX_AUDIO_AND_LAB_GUIDE.md`](../../docs/SFX_AUDIO_AND_LAB_GUIDE.md).

## 1. Tabla Contractual ("Qué cambiar → Archivo exacto")

| Objetivo del cambio | Archivo o recurso exacto | Qué tocar / evitar |
|---|---|---|
| **Cambiar / reemplazar WAV de producción de cualquier slot** | Preferido: UI de `SfxLab` (`sandbox/workbenches/sfx_lab/sfx_lab.tscn`)<br>CLI: `tools/normalize_sfx.py` → `assets/audio/sfx/` y `assets/audio/ambience/` | Exportar a WAV PCM 16-bit normalizado (`-1 dBFS`). Si añadís variantes `_v2`..`_v5` o `_layer2`, reconstruir `default_sfx_cue_bank.tres` o cargará al hacer `reload_cue_bank()`. |
| **Ajustar volumen, pitch jitter, cooldown, polifonía o bus de un SFX** | `data/audio/default_sfx_cue_bank.tres` (`SfxCueBank` / `SfxCueData`) | **Prohibido** hardcodear volúmenes o cooldowns en lógica de combate; editar los recursos `.tres`. |
| **Cambiar la familia sonora de un arma** | `data/weapons/**/*.tres` → propiedad `sfx_key: String` | Usar una de las 7 familias: `weapon_laser`, `weapon_railgun`, `weapon_shotgun`, `weapon_missile`, `weapon_blade`, `weapon_tesla`, `weapon_void`. |
| **Ajustar ducking DSP o LowPass táctico** | `core/audio/audio_mix_director.gd` y `default_bus_layout.tres` | Los 7 buses canónicos son: `Master`, `Music`, `SFX`, `Ambience`, `SFX_Combat`, `SFX_Heroic`, `SFX_UI`. |
| **Ajustar crossfade Hub ↔ Cosmos / Title** | `core/audio/ambience_crossfade_controller.gd` | Disparo vía `AudioManager.set_ambience(&"hub" | &"cosmos" | &"title")`. |
| **Modificar o agregar presets de SfxLab** | `sandbox/workbenches/sfx_lab/curated_presets.json` y `sfx_lab_catalog.gd` | Mantener rutas relativas a `sandbox/workbenches/sfx_lab/packs/` (`.wav` o `.ogg`, el resolvedor acepta ambas). |
| **Añadir o editar audios fuente en la librería compartida** | `sandbox/workbenches/sfx_lab/packs/` | Debe conservar `.gdignore` vacío para que Godot no importe los 699 archivos OGG de librería en builds de producción. |

## 2. Contratos de Llamada (No Romper)

1. **Firma de `AudioManager`:**
   - `AudioManager.play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0)`
   - `AudioManager.play_sfx_at(sfx_name: String, world_pos: Vector2, pitch_scale: float = 1.0, volume_db: float = 0.0)`
   - **¡Atención!** El 2º parámetro es `pitch_scale` (ej. `0.95`–`1.15`) y el 3º es `volume_db` (ej. `-4.0`..`+2.0`). Nunca invertirlos.
2. **Enfriamiento táctico (Modales):** Usar `AudioManager.set_tactical_focus(active: bool)` — aplica LowPass suave sobre `SFX_Combat` sin silenciar UI (`SFX_UI`).
3. **Respetar `.gdignore` y UTF-8 sin BOM:** Nunca escribir archivos `.tres` o `.gd` con PowerShell 5.1 `Set-Content -Encoding UTF8` (inserta BOM UTF-8 que rompe Godot).

## 3. Zonas Prohibidas de Exploración Blindada
- No listar recursivamente `sandbox/workbenches/sfx_lab/packs/` ni `assets/audio/sfx/`. Usar `sandbox/workbenches/sfx_lab/sfx_lab_catalog.gd` o `curated_presets.json` para consultar los 32 slots y rutas.

## 4. Comandos de Verificación
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_sfx_lab" -TimeoutSeconds 35
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_audio_manager_v2" -TimeoutSeconds 30
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_audio_anti_fatigue" -TimeoutSeconds 30
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_pause_audio" -TimeoutSeconds 30
```
