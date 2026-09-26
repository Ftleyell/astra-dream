# Astra Dream (Pre-Alpha v0.4.1)

Roguelite de acción híbrido desarrollado en **Godot 4.7+ (GDScript)** que combina combate Danmaku 360°, acumulación sinérgica de artefactos espaciales, mazo dinámico de mejoras de atributos in-run, filtrado estratégico de suministros en el Hangar y narrativa reactiva con modulación acústica dinámica (*Dialogic 2.0*).

---

## ⚡ Jugar Ahora (Descarga Rápida - 1 Solo Comando)

No necesitas instalar Godot ni clonar el repositorio. Puedes descargar el launcher autocontenido directamente a tu Escritorio y comenzar a jugar con un solo comando en **PowerShell**:

```powershell
irm https://github.com/Ftleyell/astra-dream/raw/master/AstraLauncher.exe -OutFile "$env:USERPROFILE\Desktop\AstraLauncher.exe"; & "$env:USERPROFILE\Desktop\AstraLauncher.exe"
```

> [!TIP]
> **¿Cómo funciona?**
> 1. Descarga el ejecutable portable `AstraLauncher.exe` directamente a tu Escritorio.
> 2. Lo inicia de inmediato, desempaquetando los recursos e iniciando el juego con el Hangar 3D y combate Danmaku.
> 3. En adelante, puedes abrir el juego directamente haciendo doble clic sobre el acceso directo **AstraLauncher.exe** de tu Escritorio.

### 📥 Descarga Manual
Si prefieres descargarlo manualmente a través de tu navegador:
* **[Descargar AstraLauncher.exe (Build Standalone)](https://github.com/Ftleyell/astra-dream/raw/master/AstraLauncher.exe)**

---

## 📝 Notas del Parche / Registro de Actualizaciones (v0.4.1 - Master)

### 🚀 Últimas Novedades y Sistemas Implementados

#### 🎯 Armamento Balístico Autónomo (Capa Pasiva Rediseñada)
* **Trayectoria Balística Directa:** Los misiles de apoyo ya no corrigen su curso artificialmente en el aire; ahora vuelan en línea recta estricta a alta velocidad, pudiendo impactar a enemigos en su paso o errar si el objetivo maniobra con rapidez.
* **Fijación Táctica Automática:** El sistema prioriza automáticamente al hostil más próximo dentro del perímetro de disparo efectivo de la nave.
* **Escalado del Radio de Autoaim:** Rango base fijado en el doble del radio de atracción magnética de la nave ($2 \times \text{pickup\_radius}$ base), escalando 1:1 de forma lineal con cualquier mejora o bono de imán adquirido.
* **Conmutación Manual al Cursor (Tecla `E` / Botón `RB`):** Alterna instantáneamente entre el apuntado inteligente y el disparo dirigido hacia el puntero del ratón, con feedback auditivo táctico.
* **Indicador Flotante e Interfaz:** Display táctico `AUTOAIM: ON / OFF` ubicado bajo el chasis de la nave a `(0, 26)` con micro-pulso reactivo y retícula holográfica en pantalla.

#### ⚡ Maniobras Evasivas Avanzadas (Dashes Únicos por Heroína)
* **Nova:** Doble carga de propulsión con rastro ígneo continuo que daña a los enemigos rezagados.
  * **Nova - Omega Spin:** Al dashear teniendo el condensador láser al 100% de carga, Nova desata un giro continuo de 360° barriendo toda la pantalla con su rayo láser, rotando visualmente la nave con deduplicación de daño (máximo 1 impacto por hostil).
* **Valentina:** Salto de repliegue táctico en dirección opuesta a la mira, dilatación temporal (*Bullet-Time* al 55% de velocidad de juego) y proyectil crítico 100% garantizado en su próximo disparo.
* **Kira:** Despliegue de mina señuelo reactiva en las coordenadas de partida que atrae la atención hostil y detona en área al expirar.
* **Selene:** Salto cuántico de fase de 240px en la dirección de la mira, generando un vórtice gravitacional que atrae y desestabiliza a los enemigos cercanos.
* **Roxy:** Embestida sísmica pesada con disipación frontal de proyectiles enemigos e impacto cinético con knockback masivo.
* **Echo:** Parpadeo dimensional instantáneo de 200px con descarga de relámpago en arco que encadena daño entre objetivos próximos.

#### 🌌 Hangar Estelar 3D & Mirador Panorámico
* **Entorno Híbrido 2.5D:** Hangar espacial tridimensional con iluminación ambiental, máquinas arcade interactivas, avatares de cuerpo completo y mirador panorámico al cosmos exterior.
* **Fondo Estelar Multicapa:** Simulación de 3 capas de parallax gigantes con velocidad diferencial y transparencia etérea.
* **Árbol de Talentos Permanente:** 13 nodos navegables con teclado (`WASD`) o mando, desbloqueando mejoras permanentes de chasis, blindaje, daño y aceleración.

#### 🖥️ Soporte Integral Panorámico y Ultrawide (21:9 & 32:9)
* **Anclaje Perimétrico Dinámico de Diálogos:** Los retratos de personajes en cinemáticas y diálogos de novela visual (*Dialogic 2.0*) se adaptan dinámicamente a monitores ultrapanorámicos (21:9, 32:9 y 16:10), manteniéndose permanentemente acoplados a los bordes exteriores de la pantalla sin flotar hacia el centro ni generar huecos negros descompensados.

#### 📡 Radar Perimétrico Orbital & HUD Táctico
* **Seguimiento Perimétrico:** Marcador holográfico dinámico en los márgenes de la pantalla que rastrea la ubicación de satélites de suministros y monolitos lejanos.
* **Desprendimiento Central:** Al entrar en el campo visual del jugador, el indicador se desprende del borde de la pantalla y se acopla directamente sobre el satélite u objetivo.
* **HUD Informativo:** Medidores de blindaje, condensador de carga láser, temporizador de oleada y contadores de biomasa, créditos y materia oscura.

---

## 🛠 Requisitos de Entorno para Desarrolladores
* **Godot Engine 4.7+ (Stable)**
* **Git** con soporte para **Git LFS** (`git lfs install`)
* **PowerShell 5.1+ / 7+** (incluido de serie en Windows 10/11)

---

## 🚀 Puesta en Marcha Rápida (Entorno de Desarrollo en 1 Clic)

Si vas a colaborar o ejecutar el juego desde la copia del repositorio:

```powershell
# 1. Clonar el repositorio
git clone https://github.com/Ftleyell/astra-dream.git
cd astra-dream

# 2. Configurar el entorno de desarrollo y Git Hooks (Solo 1 vez)
.\setup_dev.bat
```

> [!TIP]
> **¿Qué hace `setup_dev.bat`?**
> 1. Configura los **Git Hooks automáticos** del repositorio (`.githooks/`).
> 2. Inicializa los filtros globales de **Git LFS** para garantizar la descarga íntegra de binarios pesados (PNG, GLB, WAV).
> 3. Purga cualquier textura "dummy" corrupta que haya quedado en caché.
> 4. Ejecuta una reimportación headless con Godot Engine para que todos los modelos y texturas estén 100% listos.

---

## 🔄 Flujo de Trabajo Diario: Trabajar y Lanzar Sin Problemas

Una vez ejecutado `setup_dev.bat`, no necesitas preocuparte por texturas que falten o entornos 3D desincronizados:

### 1. Actualizar el repositorio (`git pull` o cambio de rama)
Al tener activos los Git Hooks (`.githooks/post-merge` y `.githooks/post-checkout`), cada vez que ejecutes en consola:
```bash
git pull
```
o
```bash
git checkout otra-rama
```
Git ejecutará automáticamente en segundo plano la descarga de los binarios reales de Git LFS y la reimportación limpia en Godot sin intervención manual.

### 2. Lanzar el juego
Puedes lanzar el proyecto de tres maneras:
* **Opción A (Recomendada):** Haz doble clic en `dev_run.bat` (o ejecuta `.\dev_run.bat` en consola). Verifica assets, purga posibles corruptelas y abre Godot al instante.
* **Opción B (Desde el Editor de Godot):** Abre Godot Engine y carga la carpeta del proyecto.
* **Opción C (Línea de Comandos directa):** Ejecuta `godot --path .` desde tu consola habitual.

---

## 🔍 ¿Por qué ocurren conflictos de texturas 2D y entornos 3D entre PCs?

Es muy común que en proyectos con Godot y Git ocurra que en la PC de quien sube el commit todo funcione impecable, pero al pullear en otra máquina las texturas aparezcan vacías/invisibles, de 1x1 píxel o los modelos 3D fallen. Esto se debe a dos factores técnicos fundamentales:

### 1. El Runtime de Godot NO importa assets en tiempo de ejecución
Godot separa estrictamente el **Editor** del **Juego en Ejecución (Runtime)**:
* Cuando ejecutas el juego directamente (`godot --path .` o un ejecutable exportado), el motor **nunca procesa ni lee los archivos `.png`, `.jpg` o `.glb` crudos**.
* En su lugar, el juego lee exclusivamente los binarios intermedios optimizados que el Editor compila dentro de la carpeta oculta `.godot/imported/` (archivos `.ctex` para texturas y `.mesh` para modelos 3D).
* Si haces `git pull` de una nueva imagen o modelo pero lanzas el juego directamente sin abrir previamente el Editor de Godot o sin ejecutar una reimportación headless (`godot --headless --editor --quit`), el juego intentará buscar la versión compilada en `.godot/imported/`, la cual no existe o está desactualizada, provocando que el asset no cargue.

### 2. Punteros de Git LFS vs Archivos Reales
* Git LFS almacena los archivos binarios pesados en servidores dedicados y deja en el árbol de Git únicamente un archivo de texto plano de ~130 bytes con un hash (por ejemplo, `oid sha256:... size 548291`).
* Si un desarrollador hace `git pull` sin tener configurado el filtro smudge de Git LFS o sin correr `git lfs pull`, el disco solo contendrá ese archivo de texto de 130 bytes.
* Si Godot intenta leer ese texto creyendo que es una imagen PNG real, generará en `.godot/imported/` una textura "dummy" corrupta de ~500 bytes y la guardará en caché con una firma MD5 inválida.
* **El problema de persistencia:** Incluso si después ejecutas `git lfs pull` y descargas el PNG real, Godot puede conservar la caché `.ctex` corrupta hasta que se purgue manualmente.

---

## 🧰 Guía de Solución de Problemas (Troubleshooting)

Si en algún momento notas que una textura se ve deforme, en blanco, o un modelo 3D no aparece:

### Solución Rápida en 1 Comando:
Ejecuta en tu terminal de PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_assets.ps1
```
*Este script automáticamente descarga los objetos LFS pendientes, detecta y purga cualquier `.ctex` corrupto (< 1 KB) en `.godot/imported/`, y comanda a Godot en modo headless para reconstruir la caché al 100%.*

### Si Git LFS no descarga los archivos reales:
1. Asegúrate de tener Git LFS instalado en el sistema (`git-lfs --version`). Si no lo tienes, instálalo desde [git-lfs.com](https://git-lfs.com/) o vía winget: `winget install GitHub.GitLFS`.
2. Vuelve a ejecutar:
   ```cmd
   setup_dev.bat
   ```

---

## 🎮 Controles

### Teclado y Ratón (Rebindeable en Ajustes)
* **WASD:** Movimiento omnidireccional.
* **Shift / Clic Derecho:** Dash evasivo con invulnerabilidad temporal (i-frames) y maniobra única de heroína.
* **Clic Izquierdo:** Disparo del Haz Láser Perforante de pantalla completa (con cooldown en HUD).
* **E:** Alternar modo de apuntado pasivo (Autoaim / Puntero Manual).
* **Q / Espacio:** Bomba de pantalla que destruye instantáneamente todas las balas hostiles.
* **Rozar Balas (Graze):** Acercarse al núcleo de las balas enemigas otorga EXP sin recibir daño.
* **C:** Abrir el **Cockpit de Estadísticas Tácticas** (pausa de combate con desglose de las 14 estadísticas, arcanas activas y trofeos globales permanentes).
* **ESC:** Pausar partida y abrir el **Build Inspector** (artefactos equipados y mejoras de nivel obtenidas).
* **R (Mantener 1.2s):** Reinicio seguro de la run (con oscurecimiento progresivo de pantalla).
* **T:** Disparar transmisión de radio de jefe (Dialogic 2.0 con modulación dinámica de audio).
* **Tab:** Saltar diálogos instantáneamente.

### Mando / Joystick (Soporte Nativo Xbox / PS / Switch)
* **Stick Izquierdo / D-Pad:** Movimiento y navegación de menús.
* **Botón Sur (A / Cruz):** Dash / Aceptar en menús.
* **Botón Este (B / Círculo):** Bomba / Volver en menús.
* **Gatillo Derecho (RT / R2):** Disparo Láser Activo.
* **Botón Superior Derecho (RB / R1):** Alternar apuntado pasivo (Auto / Manual).
* **Start:** Menú de Pausa.
* **Select:** Saltar diálogo.

---

## 🖥 Menús y Experiencia de Usuario (UI)
* **Pantalla de Título (`title_screen.tscn`):** Bienvenida cinemática con acceso directo a las Notas de la Versión y transición al Hangar.
* **Hangar Estelar 3D (`hub_world.tscn`):** Hub interactivo para selección de heroínas, terminal de ajustes, árbol de talentos y sala de trofeos.
* **Selección de Personajes (`character_select.tscn`):** Roster de 6 heroínas con retratos vectoriales, atributos base, pasivas y enlaces de personalización.
* **Ajustes y Configuración (`settings_modal.tscn`):** Resoluciones (16:9, 21:9 Ultrawide, 16:10 Steam Deck), volumen Master/Música/SFX y remapeo completo de teclas y mando.
* **Pausa & Build Inspector (`pause_menu.tscn`):** Inspección detallada en dos columnas de artefactos equipados y mejoras activas.
* **EXP Blobs Coalescentes (`exp_blob.tscn`):** Gotas de experiencia que se fusionan por proximidad ($d \le 52\text{ px}$) en 4 tiers escalonados con atracción magnética para garantizar un rendimiento óptimo a 60 FPS.
