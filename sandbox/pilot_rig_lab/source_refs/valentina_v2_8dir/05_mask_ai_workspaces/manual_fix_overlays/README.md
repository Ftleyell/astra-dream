# Manual Fix Overlays — Valentina v2

Carpetas listas para abrir en Photoshop / Krita / GIMP poniendo la **máscara** encima de la **referencia** (mismo tamaño exacto, alineación 1:1 por píxel).

## 1. `01_cabezas_menton_se_sw/` (`1024x1024`)
- Referencia: `head_<vista>_ref_1024.png` (RGBA transparente)
- Máscara a editar: `head_<vista>_id_mask_1024.png` (fondo blanco `#FFFFFF`)
- Colores de máscara:
  - Pelo: Cyan `#00FFFF` (`RGB 0, 255, 255`)
  - Piel / Rostro / Mentón: Verde `#00FF00` (`RGB 0, 255, 0`)
  - Cuello / Traje: Azul `#0000FF` (`RGB 0, 0, 255`)
  - Monóculo / Correas: Rojo `#FF0000` (`RGB 255, 0, 0`)
- Nota: en `se` y `sw` el borde inferior del mentón tenía un pequeño desborde/corte en la máscara verde respecto al contorno negro del mentón. Además, al re-implementar se ajustará el shader de corte de cuello (`uv.y`) para que no borre la punta del mentón.

## 2. `02_perfiles_gluteo_e_w/` (`1560x1680`)
- Referencia: `<vista>_ref_1560x1680.png` (RGBA transparente)
- Máscara a editar: `<vista>_parts5_mask_1560x1680.png` (fondo blanco `#FFFFFF`)
- Colores de máscara:
  - `body_core`: Verde `#00FF00` (`RGB 0, 255, 0`)
  - `arm_r`: Rojo `#FF0000` (`RGB 255, 0, 0`)
  - `arm_l`: Azul `#0000FF` (`RGB 0, 0, 255`)
  - `leg_r` (perfil `e`): Amarillo `#FFFF00` (`RGB 255, 255, 0`)
  - `leg_l` (perfil `w`): Magenta `#FF00FF` (`RGB 255, 0, 255`)
- Nota: si editas `e` y `w` por separado aquí, al re-cortar podemos usar tus dos máscaras editadas directamente (`e` y `w`). En `_guias_referencia/` tienes una vista previa con los pivotes `Pelvis` / `Thigh_R` / `Thigh_L` actuales.

Cuando termines de ajustar las máscaras (guardando sobre `head_*_id_mask_1024.png` y `*_parts5_mask_1560x1680.png` sin cambiar el tamaño), avísame para volver a cortar e implementar en el rig.
