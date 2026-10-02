# Pipeline de Generación de Assets y Chromas de Skins

> Guía técnica integral para la creación de arte mediante Inteligencia Artificial (Gemini) y procesado automatizado en Python para Astra Dream.

---

## 1. Generación de Sprites Cenitales (Top-Down 90°)

Para naves, enemigos, armas y satélites del núcleo de combate 2D, es esencial que los modelos no tengan inclinación isométrica para encajar con el sistema de rotación angular del jugador.

### Fórmula de Prompting Recomendada para Gemini

```text
Game asset sprite, pure top-down perspective, strictly 90-degree bird's-eye overhead angle, flat 2D game asset, [DESCRIPCIÓN DEL ASSET], sci-fi mecha aesthetic, sharp clean line art, studio lighting, isolated on solid bright chroma key [COLOR] background, no shadows on ground, no isometric angle, no perspective tilt.
```

### Reglas Críticas de Perspectiva
1. **Ángulo Estricto:** Siempre especificar `strictly 90-degree bird's-eye overhead angle, no isometric tilt`.
2. **Sin Sombras de Suelo:** `no shadows on background floor` evita que el suelo proyecte sombras semitransparentes difíciles de recortar.
3. **Iluminación Uniforme:** `even ambient lighting, no extreme directional rim light from background`.

---

## 2. Selección Estratégica del Fondo Chroma Key

El mayor error al generar con IA es usar siempre verde chillón (`#00FF00`). Si el personaje o nave tiene detalles verdes o cian, el recorte dañará el asset. Sigue esta regla:

| Paleta Dominante del Sprite | Fondo Chroma Key Recomendado | Argumento para el Script |
| :--- | :--- | :--- |
| Naves rojas, naranjas, amarillas, doradas o grises | **Verde Chroma Puro** (`#00FF00`) | `--key green` |
| Naves verdes, turquesas, cian, esmeraldas o azules | **Magenta Puro** (`#FF00FF`) | `--key magenta` |
| Sprites de plasma violeta o púrpura | **Verde o Cian Brillante** | `--key green` o `--key cyan` |

---

## 3. Eliminación Automatizada de Fondo (`chroma_remover.py`)

El script [`scripts/tools/chroma_remover.py`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scripts/tools/chroma_remover.py) analiza los píxeles en el espacio de color cilíndrico **HSV** (Hue, Saturation, Value), lo que permite separar el fondo incluso si la IA generó pequeñas variaciones de tono o brillo. Además, aplica un filtro de **despill** para limpiar el halo residual en los bordes.

### Uso Básico: Un solo archivo
```powershell
python scripts/tools/chroma_remover.py -i ruta/entrada_con_fondo.png -o assets/weapons/arma_limpia.png --key green
```

### Uso en Lote: Carpeta completa
```powershell
python scripts/tools/chroma_remover.py -i scratch/raw_ai_renders/ -o scratch/cleaned_sprites/ --key magenta --tolerance 0.09
```

---

## 4. Pipeline de Skins y Chromas Masivos (`generate_chromas.py`)

Astra Dream utiliza el concepto de **Chromas** (variantes de coloración alternativas) desbloqueables en la Máquina de Gacha del Hangar 3D. 

A partir de **una única ilustración base transparente** (ej. `fullbody_nova.png`), el script [`scripts/tools/generate_chromas.py`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/scripts/tools/generate_chromas.py):
1. **Aísla y Protege:** Detecta automáticamente los rangos cromáticos de piel humana / anime (matices cálidos anaranjados y melocotón) y las zonas neutras de ojos y pupilas, dejándolos 100% intactos.
2. **Recolorea Blindajes y Ropa:** Modula el matiz (*Hue Shift*), la saturación y el valor de las partes metálicas, ropaje, alerones y efectos de luz.
3. **Genera Variantes:** Produce en 1 segundo las variantes canónicas de Astra Dream:
   - `void`: Armadura oscura abisal con resplandores violeta amatista.
   - `neon`: Estilo cyberpunk con gris grafito y líneas turquesa/cian.
   - `solar`: Chapado en oro resplandeciente con núcleos ámbar.
   - `crimson`: Pintura de guerra carmesí y acabados en ónix.
   - `emerald`: Blindaje ceremonial de jade cuántico y verde esmeralda.
   - `amethyst`: Acabado iridiscente en orquídea eléctrica.

### Comando para Generar Todos los Chromas
```powershell
python scripts/tools/generate_chromas.py -i assets/characters/fullbody/fullbody_nova.png -o assets/characters/skins/nova/
```

Salida generada:
- `fullbody_nova_void.png`
- `fullbody_nova_neon.png`
- `fullbody_nova_solar.png`
- `fullbody_nova_crimson.png`
- `fullbody_nova_emerald.png`
- `fullbody_nova_amethyst.png`

---

## 5. Inserción Directa en el Juego (`CosmeticsManager`)

Una vez generadas las texturas:
1. Coloca los PNG en `assets/characters/skins/[pilot_id]/`.
2. Registra la skin en `core/systems/cosmetics_manager.gd`:
   ```gdscript
   "nova_void": {
       "pilot_id": "nova",
       "display_name": "Nova - Abisal Void",
       "texture_path": "res://assets/characters/skins/nova/fullbody_nova_void.png",
       "glow_hex": "#9B51E0",
       "accent_hex": "#BB6BD9",
       "banner": "pilots"
   }
   ```
3. El sistema de shaders espaciales aplicará automáticamente el efecto holográfico según el nivel de estrellas (1★ textura limpia, 2★ pulsación leve, 3★ aura de partículas y glow bloom espacial).
