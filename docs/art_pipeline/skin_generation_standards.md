# Estándar Oficial de Generación de Skins — Astra Dream

Este documento establece las especificaciones técnicas y convenciones del pipeline de generación de cosméticos y skins de producción en Astra Dream.

---

## 1. Personajes y Retratos de Selección (`selection_*.png`)

Para los pilotos y retratos de alta resolución, se adopta el flujo **Color ID Map + Tratamiento Híbrido Multimaterial**.

### 1.1 Estructura de la Máscara en Photoshop (`selection_<pilot>_mask.png`)
* **Dimensiones:** Idénticas al sprite base en píxeles (ej. $1200 \times 1600$).
* **Fondo:** Transparente (o Negro `#000000`).
* **Canales de Identidad (Colores Planos 100% Saturados):**
  * **Rojo Puro (`#FF0000` / RGB `255, 0, 0`):** Toda la ropa, armadura y exo-traje.
  * **Verde Puro (`#00FF00` / RGB `0, 255, 0`):** Todo el cabello.
  * **Azul Puro (`#0000FF` / RGB `0, 0, 255`):** Iris de los ojos y pupilas (y visores/cristales de la cabeza).
  * **Piel y Rostro:** Transparente (100% protegidos por el arnés).

### 1.2 Reglas de Tratamiento por Zona
1. **Ropa (Smart Multi-Material):**
   * El script descompone automáticamente el canal Rojo en 4 sub-materiales analizando la luminancia y saturación original del asset:
     * **Mono Base:** Recibe el gradiente del color temático (60%).
     * **Placas de Blindaje Claras / Rodilleras:** Conservan su acabado de blindaje blanco perlado, titanio pulido u oro de contraste (30%).
     * **Visor / Cristales Secundarios:** Tono de contraste armónico o acento emisivo (10%).
     * **Juntas, Suelas y Ranuras:** Mantienen densidad mecánica oscura (grafito/caucho).
2. **Cabello (Modulación Suave / Orgánica):**
   * Prohibido aplicar gradientes planos agresivos que aplanen las sombras y raíces.
   * Modulación de tonos medios al $60\%\text{–}65\%$ conservando las sombras profundas originales del dibujo y los reflejos de luz blanca anime (*highlights*).
   * **Especificación Cabello Negro (Gótica):**
     * **General (Nova, Valentina, Kira, Selene, Roxy, Nyx):** Técnica 2 (*Midnight Blue / Cuervo*): Gamma 1.35, negro (10, 12, 22), medios índigo (25, 32, 50), brillos celestes tenues (175, 195, 225).
     * **Echo (Androide Sintética):** Técnica 5 (*Black Velvet / Sangre Negra*): Gamma 1.40, negro (16, 8, 10), medios caoba/ahumado (42, 22, 26), brillos suaves (210, 190, 195).
3. **Ojos (Iris Cristalino):**
   * Tiñe únicamente el iris manteniendo la pupila negra profunda y el punto de brillo especular blanco puro.
   * Sin halos de linterna desbordados salvo en skins legendarias tipo androide donde se especifique modo emisivo.

---

## 2. Armas y Exo-Cañones (`weapon_*.png`)

Para armas y equipamiento mecha, se adopta el flujo **Zero-Mask Smart Decomposition (100% Algorítmico)**:

### 2.1 Descomposición Automática por Histograma y Luminancia
Sin necesidad de pintar máscaras manuales en Photoshop, el script aísla los 4 componentes mecha:
1. **Paneles Modulares Exteriores ($L \ge 175$):** Paneles de la carcasa que reciben el color insignia de la skin con reflejos metálicos limpios.
2. **Chasis Estructural ($75 < L < 175$):** Cuerpo interior y tubos del cañón tratados como aleación pesada (Titanio oscuro, tungsteno o acero suizo).
3. **Ranuras y Pernos ($L \le 75$):** Oclusión profunda y sombras mecánicas protegidas en negro carbón mate.
4. **Sensor Óptico / Lente Central:** Inyección de energía reactiva con resplandor suave (*bloom* aditivo en modo Screen).

---

## 3. Scripts Oficiales de Herramientas
* **Banco de Pruebas de Personajes:** [`tools/test_soft_hair_eyes.py`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/tools/test_soft_hair_eyes.py)
* **Pipeline Smart Multi-Material de Armas:** [`tools/test_weapon_smart_multimaterial.py`](file:///c:/Users/Frani/.gemini/antigravity/scratch/astra_dream/tools/test_weapon_smart_multimaterial.py)
