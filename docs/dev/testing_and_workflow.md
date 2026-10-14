# Flujo de Desarrollo, Pruebas y Buenas Prácticas — Astra Dream

Guía definitiva para desarrolladores y agentes de IA sobre testing automatizado, convenciones de código y Git.

---

## 1. Arnés de Pruebas Automatizadas (Testing Harness)

El proyecto cuenta con un ejecutor headless anti-cuelgues con timeout automático (`tools/run_tests.ps1`).

### Ejecución Rápida y Aislada (Obligatorio durante el Desarrollo Activo)
Durante la programación o corrección de bugs, ejecutar **únicamente** la suite de pruebas del componente afectado. El arnés soporta coincidencia recursiva por subcadena:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "<subcadena>"
```

### Tabla de Atajos de Pruebas por Dominio (2 a 7 segundos)

| Dominio | Subcadena para `-Test` | Suite que Ejecuta |
|---|---|---|
| **Cosmos / Fondo Espacial** | `"space_environment"` | `tests/unit/test_space_environment_integration.tscn` |
| **Órbitas y Anti-Snapping** | `"orbital_binding_events"` | `tests/unit/test_orbital_binding_events.tscn` |
| **Slots Analíticos y Binding** | `"gameplay_orbital_binding"` | `tests/unit/test_gameplay_orbital_binding.tscn` |
| **Fachada Host Cósmica** | `"cosmos_host_controller"` | `tests/unit/test_cosmos_host_controller.tscn` |
| **Smoke Packaging Cosmos** | `"cosmos_packaging_smoke"` | `tests/unit/test_cosmos_packaging_smoke.tscn` |
| **HUD / Dragon Radar** | `"dragon_radar"` | `tests/test_dragon_radar_runner.tscn` |
| **HUD / Radar Satelital** | `"satellite_edge_indicator"` | `tests/test_satellite_edge_indicator_runner.tscn` |
| **HUD / Polish General** | `"phase1_ui_polish"` | `tests/test_phase1_ui_polish_runner.tscn` |
| **Armas y Balística** | `"weapons"` | `tests/test_weapons_runner.tscn` |
| **Jefes y Encuentros** | `"boss"` | `tests/test_boss_runner.tscn` |
| **Jefe Rival** | `"rival_engagement_rules"` | `tests/test_rival_engagement_rules_runner.tscn` |
| **Persistencia y Serialización** | `"persistence"` | `tests/test_persistence_runner.tscn` |
| **Satélites y Tiendas** | `"satellite_items"` | `tests/test_satellite_items_runner.tscn` |
| **Cofres y Economía** | `"chest_economy"` | `tests/test_chest_economy_runner.tscn` |
| **Tragamonedas y Gacha** | `"slot_machine_and_gacha"` | `tests/test_slot_machine_and_gacha_runner.tscn` |
| **Pausa y Tokens** | `"pause_arbitrator"` | `tests/test_pause_arbitrator_runner.tscn` |

### Verificación Integral (Pre-Commit / Fin de Tarea)
Para verificar la suite completa antes de integrar cambios:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
```
*(Ejecuta las 23 suites clave con timeout de 15s por suite y reporte resumido).*

### Contrato de Nuevas Pruebas
Toda nueva suite de pruebas unitarias o de integración debe heredar de `BaseTestSuite` (`tests/base_test_suite.gd`).

---

## 2. Convenciones de GDScript 4

1. **Tipado Estricto al 100%:**
   - Todas las variables miembro, locales, parámetros de función y retornos deben estar tipados:
     ```gdscript
     var current_speed: float = 0.0
     func calculate_trajectory(delta: float) -> Vector2:
     ```
2. **Modularidad Estricta (Anti God-Objects):**
   - Prohibido acumular lógica en escenas raíz (`main_game.gd`, `player.gd`, `hub_world.gd`).
   - Usar controladores, builders y componentes especializados con responsabilidad única.
3. **Cero Números Mágicos:**
   - Valores numéricos de juego y balance residen en Custom Resources `.tres`.
4. **Higiene de Setters y Ciclo de Vida:**
   - Prohibido asumir que nodos hijos, cámaras o autoloads están resueltos dentro de un setter de propiedad. Usar guardas y validaciones `is_instance_valid()`.

---

## 3. Flujo de Git y Commits

- Todo commit debe realizarse con mensajes en inglés según la convención Conventional Commits:
  - `feat(<scope>): ...`
  - `fix(<scope>): ...`
  - `refactor(<scope>): ...`
  - `docs(<scope>): ...`
  - `test(<scope>): ...`
- En sesiones asistidas por IA, consultar y confirmar siempre los cambios de commit mediante cuestionarios interactivos (`ask_question`).
