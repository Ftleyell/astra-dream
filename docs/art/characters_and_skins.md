# Ficha Técnica de Arte: Personajes, Skins y Armamento

Especificación compacta para la creación de heroínas, skins cosméticas, armas y retratos narrativos en **Astra Dream**.

---

## 1. Roster de Heroínas y Vinculación con Recursos (.tres)

| Piloto | Recurso Base (`.tres`) | Color Temático (HEX) | Arma Inicial (`.tres`) | Arquetipo / Silueta |
|---|---|---|---|---|
| **Nova** | `data/characters/nova.tres` | Cian Neón (`#1AE6FF`) | `data/weapons/roster/rail_launcher.tres` | Asalto / Exo-caza estilizado con toberas gemelas |
| **Valentina** | `data/characters/valentina.tres` | Fucsia Neón (`#FF007F`) | `data/weapons/roster/scatter_laser.tres` | Francotiradora / Chasis angular aerodinámico y cañones largos |
| **Kira** | `data/characters/kira.tres` | Verde Neón (`#39FF14`) | `data/weapons/roster/swarm_missiles.tres` | Enjambre / Alas plegables con bahías de micro-drones |
| **Selene** | `data/characters/selene.tres` | Violeta Psiónico (`#BF00FF`)| `data/weapons/roster/void_siphon.tres` | Mística / Casco con velo bio-energético y formas orgánicas |
| **Roxy** | `data/characters/roxy.tres` | Naranja Fuego (`#FF5F00`) | `data/weapons/roster/plasma_flak.tres` | Tanque Pesado / Blindaje macizo reforzado con ariete frontal |
| **Echo / Nyx** | `data/characters/echo.tres` | Amarillo Cósmico (`#FFE600`)| `data/weapons/roster/crescent_blade.tres` | Ciber-Sigilo / Estela de fases dimensionales y hojas de plasma |

---

## 2. Nomenclatura y Pipeline de Skins Cosméticas

Los sprites de skins deben almacenarse con rutas estandarizadas respetando el ID de skin:
`assets/sprites/characters/<pilot_id>/<skin_id>/`

* **Ejemplo Nova:**
  * `nova_base.png` (Aspecto por defecto)
  * `nova_cyberpunk.png`
  * `nova_starlight.png`

### Estándar de Retratos Narrativos (Dialogic 2)
1. **Dimensiones:** `512 x 768 px` en PNG-32.
2. **Emociones Base:**
   * `neutral.png` (Por defecto)
   * `happy.png` / `smirk.png`
   * `angry.png` / `combat.png`
   * `shocked.png` / `alert.png`
3. **Orientación:** Mirando hacia la derecha (lado del jugador en diálogos) por defecto. Dialogic aplica espejo horizontal para interlocutores opuestos.

---

## 3. Arsenal de Armas (Iconos y Proyectiles)

| ID del Arma | Recurso (`.tres`) | Estilo Visual del Proyectil | Color Principal (HEX) |
|---|---|---|---|
| `rail_launcher` | `data/weapons/roster/rail_launcher.tres` | Proyectil cónico de aceleración magnética con estela de partículas | `#1AE6FF` |
| `plasma_flak` | `data/weapons/roster/plasma_flak.tres` | Célula de energía inestable que detona en racimo circular | `#FF5F00` |
| `swarm_missiles` | `data/weapons/roster/swarm_missiles.tres` | Micro-cohetes dirigidos con estela de humo estilizada | `#39FF14` |
| `void_siphon` | `data/weapons/roster/void_siphon.tres` | Orbe espiral gravitatorio con vórtice oscuro central | `#BF00FF` |
| `scatter_laser` | `data/weapons/roster/scatter_laser.tres` | Haces láser paralelos coherentes de alta velocidad | `#FF007F` |
| `crescent_blade` | `data/weapons/roster/crescent_blade.tres` | Tajos cortantes en arco de media luna con deformación espacial | `#FFE600` |
| `tachyon_beam` | `data/weapons/roster/tachyon_beam.tres` | Haz continuo perforante con shader de pulso interior | `#00FFAA` |
| `singularity_cannon` | `data/weapons/roster/singularity_cannon.tres`| Microagujero negro con distorsión de refracción óptica | `#8A2BE2` |
