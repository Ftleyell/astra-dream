# Testing Workflow y Guía de Tests Anti-Cuelgue — Astra Dream

> **Propósito:** Definir la pirámide de pruebas, los tipos de test existentes en Astra Dream y cómo añadir nuevos tests garantizando un ciclo de retroalimentación rápido (< 2.5s) y cero cuelgues (anti-hang).

---

## 🏔️ Pirámide de Pruebas

```
                   ▲
                  / \
                 /   \
                / L3  \   CoreOnly Suites (Integración Integral)
               /-------\  powershell -File tools/run_tests.ps1 -CoreOnly (~80s)
              /   L2    \ Feature Suites (Bajo demanda al tocar subsistemas)
             /-----------\ powershell -File tools/run_tests.ps1 -Test "<suite_runner.tscn>" (4-8s)
            /     L1      \ Fast Unit Tests (Síncronos, lógica de negocio pura)
           /---------------\ powershell -File tools/run_unit_fast.ps1 (2-10s)
```

### 1. Nivel 1: Fast Unit Tests (`tests/unit/`)
- **Propósito:** Validar lógica de negocio matemática, reglas de filtrado, persistencia en `SaveManager`, conversiones numéricas y controladores desacoplados.
- **Tiempo de ejecución:** < 2.5s por suite.
- **Herramienta de ejecución:** `powershell -ExecutionPolicy Bypass -File tools/run_unit_fast.ps1`.
- **Características clave:**
  - **Sin árbol UI masivo ni simulación de cuadros innecesarios.**
  - Blindados con Watchdog autónomo de 3.0s y un Circuit Breaker a nivel shell (8.0s) que previene bloqueos de consola.

### 2. Nivel 2: Feature Integration Tests (`tests/`)
- **Propósito:** Verificar interacción entre nodos, escenas visuales completas, modales y respuestas de input.
- **Tiempo de ejecución:** 3s a 8s.
- **Herramienta de ejecución:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "<suite_runner.tscn>"`.
- **Regla:** Ejecutar **únicamente** la suite específica del subsistema afectado durante la iteración activa.

### 3. Nivel 3: CoreOnly Suite (`tools/run_tests.ps1 -CoreOnly`)
- **Propósito:** Validación integral antes de crear un commit de hito o cerrar una sesión.
- **Regla:** **Prohibido** ejecutar de forma repetitiva en pasos intermedios.

---

## 🛡️ Pautas para Crear Tests Seguros Anti-Cuelgue

1. **Heredar de `BaseTestSuite`:**
   Toda nueva suite de prueba DEBE extender de `BaseTestSuite` (`res://tests/base_test_suite.gd`).

2. **Nunca hacer `await` a señales sin límite de tiempo:**
   Usar siempre el helper anti-cuelgue provisto por `BaseTestSuite`:
   ```gdscript
   var received := await await_signal_or_timeout(my_node.some_signal, 2.5)
   assert_true(received, "La señal debió emitirse antes del timeout")
   ```

3. **Cierre explícito de la suite:**
   Al finalizar todas las afirmaciones, llamar a:
   ```gdscript
   pass_suite("NombreDeLaSuite completamente aprobada")
   ```
