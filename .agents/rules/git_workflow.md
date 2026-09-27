---
trigger: model_decision
description: "Protocolo de cuestionarios interactivos de Git, ramas, convenciones de commit en inglés y sincronización."
---

# Flujo de Git y Convenciones de Commits

1. **Momento de Ejecución:**
   - La interacción de Git se realiza únicamente tras haber finalizado todos los cambios de código y validado las pruebas automatizadas.
2. **Cuestionarios Interactivos (`ask_question`):**
   - Siempre consultar el destino de ramas y títulos de commits usando `ask_question`.
3. **Conventional Commits en Inglés:**
   - Mensajes de commit redactados en inglés siguiendo `feat(<scope>): <description>`, `fix(...)`, `refactor(...)`, etc.
