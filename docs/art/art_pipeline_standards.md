# Pipeline de Arte y Estándares Visuales — Astra Dream

Guía canónica para la creación, procesamiento e importación de assets 2D y 3D en Astra Dream.

---

## 1. Estándares de Sprites y Skins

- **Retratos y Avatares de Pilotos:**
  - Resolución canónica: Cuadrados de **512x512 px** (o 1024x1024 px para retratos de diálogo de alta fidelidad).
  - Formato: PNG con canal alfa transparente limpio.
  - Estilo artístico: Anime scifi / Mecha cósmico con líneas limpias y sombreado cel-shaded.
- **Skins y Variaciones Cromáticas:**
  - Las skins son gestionadas mediante `CosmeticsManager` (`core/systems/cosmetics_manager.gd`).
  - La selección en UI se realiza mediante el componente desacoplado `CosmeticCarouselModal`.

---

## 2. Fondo Espacial y Debris Cósmico

- **Arquitectura de Capas de Fondo:**
  - El fondo espacial es orquestado por `SpaceEnvironmentHost` (`scenes/combat/environment/space_environment_host.gd`).
  - Implementa múltiples planos de paralaje desacoplados (polvo estelar, nebulosas lejanas, planetas en órbita y asteroides de primer plano).
- **Debris Espacial y Macro-Objetos:**
  - Controlado por `CombatSpaceDebrisManager`.
  - Los restos de naves y asteroides se generan proceduralmente fuera de pantalla y se reciclan al alejarse del rango de visión del jugador.

---

## 3. Optimización de Texturas y Shaders

- **Compresión de Texturas:**
  - UI y HUD: Compresión Lossless o VRAM Uncompressed con bordes nítidos.
  - Elementos de fondo y nebulosas: Compresión VRAM BPTC/ETC2 para reducir el consumo de memoria en GPU.
- **Shaders de Impacto y Daño:**
  - Todo destello de daño (*flash hit*) o efecto de escudo utiliza shaders de CanvasItem optimizados sin lectura repetida de screen texture.
