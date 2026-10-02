# Ficha Técnica de Arte: Entornos, Destructibles y VFX

Directrices técnicas para fondos espaciales en paralaje, macro-objetos destructibles y efectos visuales cinemáticos en **Astra Dream**.

---

## 1. Pipeline de Fondos en Paralaje Espacial (3 Capas)

| Capa | Factor de Paralaje | Contenido Visual | Resolución / Tiling |
|---|---|---|---|
| **Capa 1: Fondo Lejano (Nebulosa)** | `0.05 - 0.10` | Nebulosas estelares, cúmulos de gas y planetas gigantes distantes. | `2048 x 2048 px` seamless tile o gradiente procedural. |
| **Capa 2: Fondo Medio (Campo Estelar)** | `0.25 - 0.35` | Estrellas de brillo medio, polvo estelar tenue y estaciones espaciales remotas. | `1024 x 1024 px` repetible con transparencia. |
| **Capa 3: Primer Plano Inmediato** | `0.70 - 0.85` | Partículas flotantes de hielo, escombros finos y micro-meteoritos fuera de foco. | Emisores de partículas 2D (`CPUParticles2D` / `GPUParticles2D`). |

---

## 2. Macro-Objetos Espaciales Destructibles

Los obstáculos neutros y minerales destructibles deben responder a impactos balísticos con estados de fractura legibles:

| Objeto | Dimensiones (px) | Hitbox (Radio) | Fases de Destrucción | Recompensa Visual |
|---|---|---|---|---|
| **Asteroide Metálico** | `96 x 96` a `160 x 160` | `45 - 75 px` | Intacto -> Fisurado -> Fragmentado | Fragmentos de roca y créditos volantes. |
| **Fragmento Planetario** | `256 x 256` a `384 x 384`| `120 - 180 px`| Corteza -> Manto Ígneo -> Núcleo | Desprendimiento de capas con shader `planet_crust_destruction`. |
| **Monolito Cósmico** | `128 x 256` | Elíptica `50 x 110 px`| Glifos apagados -> Sobrecarga -> Quiebre | Pulso de energía psiónica y orbe arcano. |
| **Geoda de Cristal** | `80 x 80` | `38 px` | Caparazón rocoso -> Cristal expuesto | Dispersión de cristales de BioMasa verdes/azules. |

---

## 3. Estándares Técnicos de Efectos Visuales (VFX)

### 3.1 Estela Fantasma (Sandevistan / After-Image)
* **Objetivo:** Representar aceleración temporal o dash táctico sin sobrecargar el renderizador.
* **Técnica:** Instanciación de copias fantasma translúcidas (`modulate:a = 0.65 -> 0.0` en 0.25s) tintadas con el color temático de la heroína y leve aberración cromática.

### 3.2 Portales Hiperespaciales y Ruptura de Realidad (`CosmicRealityTear`)
* **Vórtice Dimensional:** Quads de 256x256 px animados con shader de deformación UV concéntrica (`dimensional_vortex_core.gdshader`).
* **Hoja Dimensional:** Shader cortante con bordes nítidos (`dimensional_slash_blade.gdshader`).

### 3.3 Ondas Expansivas (Shockwaves)
* **Distorsión por Pantalla:** Sprite centrado en la detonación con shader de refracción normal.
* **Parámetros de Tween:** Expansión de radio de 0 a 450 px en `0.35s` (`Ease: OUT`, `Trans: CUBIC`), desvaneciendo la fuerza de refracción a 0.
