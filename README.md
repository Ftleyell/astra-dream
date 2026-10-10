# Astra Dream — Proyecto y Visión Técnica

Astra Dream es un bullet-hell espacial / roguelite de acción desarrollado en **Godot 4.7.2 (GDScript 4)** con arquitectura modular data-driven y rendimiento Zero-Allocation.

---

## 🚀 Arquitectura y Filosofía

- **Motor:** Godot 4.7.2 stable (Windows / Multiplataforma).
- **Enfoque de Rendimiento:** Servidor de proyectiles por lotes (`BulletServer`) con arreglos de memoria contigua (`PackedFloat32Array`).
- **Arquitectura de Nodos:** Desacoplamiento estricto mediante controladores de subsistemas, contratos virtuales y componentes modulares.
- **Configuración:** Recursos Custom `.tres` para el balance y comportamiento de armas, naves y enemigos.

---

## 📂 Organización de la Documentación

Toda la documentación técnica y de diseño se organiza de forma modular en `docs/`:

1. [Arquitectura del Sistema](docs/architecture/system_architecture.md): Contratos de combate, subsistemas, modales y ciclo de vida.
2. [Servicios Globales y EventBus](docs/architecture/autoloads_and_events.md): Documentación de los 7 autoloads y catálogo de señales desacopladas.
3. [Game Design y Balance](docs/game_design/balance_and_mechanics.md): Fórmulas de mitigación, One-Shot Protection, progresión de oleadas y economía in-run.
4. [Pipeline de Arte y Assets](docs/art/art_pipeline_standards.md): Estándares para retratos, skins, fondos y VFX espaciales.
5. [Guía de Desarrollo y Testing](docs/dev/testing_and_workflow.md): Arnés de pruebas headless, convenciones de Git y contratos de tipado estricto.

---

## 🛠️ Ejecución de Pruebas

Para validar el juego mediante el arnés automatizado sin cuelgues:

```powershell
# Ejecutar un test runner específico (Recomendado en desarrollo):
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Test "test_pause_arbitrator_runner.tscn"

# Ejecutar el conjunto core:
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -CoreOnly
```
