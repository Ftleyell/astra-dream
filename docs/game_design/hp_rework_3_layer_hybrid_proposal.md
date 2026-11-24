# Propuesta de Rework Futuro de Supervivencia — *Astra Dream*
### Modelo Híbrido de 3 Capas: **Casco + Escudo Reactivo + Barrera 1-Hit**
*(Estado: Propuesta de Diseño Teórica · Inspiración: Nova Drift × Risk of Rain 2 × Returnal)*

---

## 1. Filosofía Central: *"Tu Escudo es tu Habilidad; tu Casco es tu Historia"*

En este rework, la supervivencia del jugador se divide en **tres capas con significados tácticos y emocionales distintos**, resolviendo la tensión entre el **Danmaku de precisión 360°** (`HitboxCore` de `5 px`, Graze, Focus táctico, Dash, Bombas) y el **Action Roguelite / Survivors-like** (armadura, ítems, cartas de stats, economía satelital y exploración por distancia):

- **Barrera 1-Hit (Externa):** Comodín táctico contra ataques letales o patrones de jefe.
- **Escudo Reactivo (Media):** Margen de error del combate actual. Se recupera jugando limpio y aún más rápido jugando agresivo al rozar balas (**Graze**).
- **Casco / Integridad (Interna):** Atrición persistente de toda la run. Cada punto perdido aquí tiene peso estratégico en satélites, cápsulas de campo y *Run Forks*.

El objetivo es que **esquivar siga siendo el pilar #1 hasta el final de la run**, evitando tanto el *face-tanking* por regeneración excesiva como el castigo injusto por roces aislados o derretimiento en pocos frames.

---

## 2. Las 3 Capas y el Flujo de un Impacto

Cuando una bala o enemigo impacta el `HitboxCore`, el daño se resuelve de afuera hacia adentro:

### Capa 3 (Externa) — **Barreras de Fase (Cargas 1-Hit)**
- **Qué son:** Cargas discretas (tope visual de `1` a `3`). Cada carga **anula por completo un único impacto**, sin importar su magnitud.
- **Al romperse:** Destello nítido + breve invulnerabilidad (`~0.5 s`) y **NO** reinicia el temporizador de recarga del escudo.
- **Rol:** Recurso de alto impacto exclusivo de pilotos específicos, arcanas o ítems raros (evolución formal de capas discretas como `caelia_shield_hook` y `phase_inverter_shield`).

### Capa 2 (Media) — **Escudo Energético Reactivo + *Shield-Gating***
- **Proporción base:** Entre el **25% y 40%** de la salud efectiva base (salvo builds extremas de conversión).
- **Ciclo de recarga:** Tras **`5–6 s` sin recibir daño**, el escudo se recarga rápidamente hasta el 100%.
- **Puente Danmaku (Sinergia con Graze):** Cada **Graze** mientras el escudo espera recargarse **recorta el delay de recarga** (p. ej. `-0.25 s` por bala rozada, con tope de cadencia). Si ya está recargándose, el Graze acelera el llenado.
  - *Bucle riesgo-recompensa:* Cuando te rompen el escudo, el incentivo es tejer cerca de las balas para recuperarlo rápido en vez de huir pasivamente.
- ***Shield-Gating* (Seguro anti-one-shot activo):** Cuando un golpe rompe el último punto de escudo:
  1. El daño excedente de ese golpe **se absorbe y NO sangra al casco**.
  2. Se activa una ventana de invulnerabilidad corta (`~0.65 s`).
  3. Se emite un **micro-pulso limpia-balas** en radio pequeño alrededor de la piloto (`~110 px`) para evitar muertes atrapadas dentro de cortinas densas.

### Capa 1 (Interna) — **Casco / Integridad + Armadura**
- **Qué es:** Salud numérica persistente mitigada por **Armadura hiperbólica** (`100 / (100 + armor)`).
- **Invulnerabilidad post-impacto:** Todo impacto real al casco otorga **i-frames calibrados (`~0.45 s`)** para evitar derretimientos instantáneos por múltiples balas en frames consecutivos.
- **Recuperación escasa e intencional:** Regeneración pasiva base = **`0`**. La reparación exige acción o costo (cápsulas estáticas de campo, reparación por créditos en estaciones satelitales o sinergias con *trade-off*).
- **Estado Crítico (<25% Casco):** Alerta visual/sonora persistente; zona donde escalan builds de riesgo extremo (`hemodynamic_cell`).

---

## 3. Impacto en el Combate Momento a Momento

### Jerarquía de Amenazas (Daño Diferenciado)
- **Balas ligeras / enjambre común (Daño bajo):** Solo rasguñan el escudo; si esquivas bien, nunca tocan el casco.
- **Contacto con enemigos / proyectiles medianos (Daño medio):** Rompen medio escudo o castigan el casco si estás expuesta.
- **Láseres de Jefes, ataques de Piloto Rival y patrones pesados (Daño alto):** Telegrafiados; si golpean con escudo activan *Shield-Gate* y te dejan expuesta, y si golpean sin escudo arrancan un tramo severo de casco.

### Sinergia con Herramientas Danmaku
- **Dash:** Esquiva principal con i-frames para atravesar muros sin gastar escudo ni barreras.
- **Focus Táctico:** Herramienta clave para leer el `HitboxCore` y **farmear Graze para acelerar la recarga del escudo** durante patrones de jefe.
- **Bombas:** Además de botón de emergencia, funcionan como **ventana táctica segura** para limpiar pantalla tras un *Shield-Gate* y recuperar el escudo.

---

## 4. Rework del Ecosistema: Cartas, Builds y Economía

### Cartas de Level-Up
- Eliminar o restringir fuertemente la regeneración pasiva gratuita de casco para impedir el *face-tanking* en late game.
- Cuatro ejes defensivos claros: `+Casco Máximo`, `+Armadura`, `+Escudo Máximo` y `-Delay de Escudo / +Eficiencia de Graze en Escudo`.

### Cuatro Arquetipos de Build Defensiva
1. **Tanque de Casco & Berserker:** Casco alto + Armadura + ítems de vida baja (p. ej. *Célula Hemodinámica*).
2. **Bailarina de Escudo & Graze:** Casco ligero + Escudo ágil con delay mínimo acelerado por Graze.
3. **Aegis (Coleccionista de Barreras):** Ítems/arcanas que generan cargas de Barrera 1-Hit por eliminaciones, dashes perfectos o fases de jefe.
4. **Conversión / Cañón de Cristal:** Arcanas extremas que convierten casi todo el Casco en Escudo masivo (estilo *Transcendence*) o eliminan el Escudo a cambio de Armadura y Daño puro (*Overdrain*).

### Economía Satelital, Drops y *Run Forks*
- **Cápsulas de Curación en Campo:** Recuperan valor táctico real al no existir regeneración gratuita.
- **Estaciones Satelitales:** Ofrecen **Reparación de Casco por Créditos** como decisión económica real frente a comprar armas/ítems.
- ***Run Forks*:** Sacrificar `%` de Casco o penalizar el delay de escudo a cambio de recompensas mayores adquiere peso estratégico genuino.

---

## 5. Identidad de Pilotos

| Arquetipo de Piloto | Casco | Escudo | Barrera 1-Hit | Fantasía Jugable |
|---|---|---|---|---|
| **Valentina** *(Francotiradora / Sobre-Enfoque)* | Bajo | Medio-Alto (recarga rápida + bonus Graze) | `0` | Precisión pura: jugando limpio y usando Sobre-Enfoque el escudo siempre vuelve; dos errores seguidos son letales. |
| **Nova** *(Ágil / Doble Dash)* | Medio-Bajo | Medio (delay muy corto) | `0` | Ritmo frenético con doble dash para ganar ventanas de recarga. |
| **Roxy** *(Bruiser / Embestida)* | Muy Alto + Armadura base | Bajo (recarga lenta) | `0` | Aguante físico y mitigación directa durante embestidas. |
| **Caelia** *(Táctica / Gravitacional)* | Medio | Medio-Bajo | `1` carga regenerable | Control calculado con seguro perfecto de 1 golpe en cada intercambio. |

---

## 6. Legibilidad en 1 Milisegundo: Rig Diegético + HUD

Dado que en Danmaku la mirada permanece fija en el `HitboxCore` de `5 px`, la información se presenta en dos niveles:

### Feedback Diegético en el Rig 2.5D
- **Barrera 1-Hit:** `1–3` pips/rombos luminosos orbitando sutilmente cerca del halo de la piloto.
- **Escudo activo / roto:** Halo energético sutil; al romperse (*Shield-Gate*), chasquido cristalino/eléctrico inconfundible + micro-pulso limpia-balas.
- **Escudo recargado al 100%:** Destello breve + timbre agudo suave confirmando que el seguro anti-one-shot volvió.
- **Daño al Casco:** SFX metálico grave, ligero *hitstop* y pulso rojo periférico bajo `25%`.

### HUD Unificado
- Barra integrada: **Casco (izquierda)** + **Escudo cian pegado (derecha)** con indicador de progreso del delay de recarga (que salta visiblemente con cada **Graze**) + **iconos de Barrera 1-Hit** en el borde derecho.
