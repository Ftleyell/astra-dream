# Flujo de Desarrollo, Pruebas y Buenas Prácticas — Astra Dream

Guía para desarrolladores y agentes de IA sobre testing automatizado, convenciones de código y Git.

---

## 1. Arnés de Pruebas Automatizadas (Testing Harness)

El proyecto cuenta con un ejecutor headless anti-cuelgues con timeout automático (`tools/run_tests.ps1`).

### Ejecución Rápida y Aislada (Obligatorio en Desarrollo)
Durante la programación o corrección de bugs, ejecutar **únicamente** la suite de pruebas del componente afectado:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "<nombre_del_runner>.tscn"
```
*Ejemplo:*
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_pause_arbitrator_runner.tscn"
```

### Verificación Integral (Pre-Commit / Fin de Tarea)
Para verificar la suite completa antes de integrar cambios:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
```

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
   - Valores numéricos de juego residen en Custom Resources `.tres`.

---

## 3. Flujo de Git y Commits

- Todo commit debe realizarse con mensajes en inglés según la convención Conventional Commits:
  - `feat: ...`
  - `fix: ...`
  - `refactor: ...`
  - `docs: ...`
  - `test: ...`
- Confirmar siempre los cambios de commit mediante cuestionarios interactivos.
