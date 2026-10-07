#!/usr/bin/env python3
"""Generates the 7 character skill tree .tres files with custom Texture2D icon links."""
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "data", "skill_trees")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Coordenadas estandarizadas de la constelación (escaladas 1.35x para hexágonos de 104px)
POS_CORE = "Vector2(0, 0)"
POS_SPEED_1 = "Vector2(0, -155)"
POS_SPEED_2 = "Vector2(0, -305)"
POS_SPEED_3 = "Vector2(0, -450)"
POS_DMG_1 = "Vector2(200, 0)"
POS_DMG_2 = "Vector2(380, 0)"
POS_DMG_3 = "Vector2(550, 0)"
POS_HP_1 = "Vector2(0, 155)"
POS_HP_2 = "Vector2(0, 305)"
POS_HP_3 = "Vector2(0, 450)"
POS_CRIT_1 = "Vector2(-200, 0)"
POS_CRIT_2 = "Vector2(-380, 0)"
POS_CRIT_3 = "Vector2(-550, 0)"

PILOTS_DATA = {
    "nova": {
        "core": ("NÚCLEO DE PILOTO", "Matriz neural primaria de Nova. Punto de origen de todas las rutas de hiper-conducción y energía de riel."),
        "speed": [
            ("IMPULSO VECTORIAL I", "+20% Velocidad de movimiento permanente en combate."),
            ("IMPULSO VECTORIAL II", "+20% Velocidad de movimiento permanente (+40% acumulado)."),
            ("SOBRECARGA DE POSTQUEMADOR", "+20% Velocidad de movimiento permanente (+60% acumulado)."),
        ],
        "damage": [
            ("SOBREALIMENTACIÓN TÉRMICA I", "+15% Daño general infligido permanente en combate."),
            ("SOBREALIMENTACIÓN TÉRMICA II", "+15% Daño general permanente (+30% acumulado)."),
            ("FUSIÓN DE CAÑÓN CUÁNTICO", "+15% Daño general permanente (+45% acumulado)."),
        ],
        "hp": [
            ("NANO-BLINDAJE REGENERATIVO I", "+25 Puntos de Salud Máxima permanente en combate."),
            ("NANO-BLINDAJE REGENERATIVO II", "+25 Puntos de Salud Máxima permanente (+50 HP acumulado)."),
            ("MATRIZ DE CASCO TITÁN", "+25 Puntos de Salud Máxima permanente (+75 HP acumulado)."),
        ],
        "crit": [
            ("TELEMETRÍA DE PRECISIÓN I", "+5% Probabilidad Crítica y +5% Cadencia de ataque permanente."),
            ("TELEMETRÍA DE PRECISIÓN II", "+5% Probabilidad Crítica y +5% Cadencia (+10% acumulado)."),
            ("SINCRONIZADOR HIPER-ÓPTICO", "+5% Probabilidad Crítica y +5% Cadencia (+15% acumulado)."),
        ],
    },
    "nyx": {
        "core": ("NÚCLEO CREPUSCULAR", "Matriz dimensional de Nyx. Canaliza energía del vacío hacia la Hoja Crepuscular y el motor de fase."),
        "speed": [
            ("PASO ENTRE FRENTES I", "+18% Velocidad de movimiento permanente en combate."),
            ("TRASLACIÓN FLUIDA II", "+18% Velocidad de movimiento permanente (+36% acumulado)."),
            ("SALTO DIMENSIONAL PERPETUO", "+18% Velocidad (+54% acum.) y recarga de Dash un 15% más rápida."),
        ],
        "damage": [
            ("FILO DEL CREPÚSCULO I", "+18% Daño cuerpo a cuerpo general permanente."),
            ("RESQUEBRAJADURA ESPACIAL II", "+18% Daño cuerpo a cuerpo permanente (+36% acumulado)."),
            ("SINGULARIDAD CORTANTE", "+18% Daño cuerpo a cuerpo (+54% acum.) y +15% tamaño del arco de corte."),
        ],
        "hp": [
            ("ESCUDO DE EVENTOS I", "+30 Puntos de Salud Máxima permanente en combate."),
            ("TEJIDO DIMENSIONAL II", "+30 Puntos de Salud Máxima permanente (+60 HP acumulado)."),
            ("ANCLAJE ESPACIO-TEMPORAL", "+30 HP Máxima (+90 HP acum.) y +1.0 Regeneración de HP/segundo."),
        ],
        "crit": [
            ("COMPÁS DE MEDIA LUNA I", "+6% Probabilidad Crítica y +6% Cadencia de ataque melee permanente."),
            ("RÁFAGA DE VACÍO II", "+6% Probabilidad Crítica y +6% Cadencia (+12% acumulado)."),
            ("VERDUGO DEL ECLIPSE", "+8% Prob. Crítica y +8% Cadencia (+20% acum.) y +20% Daño Crítico."),
        ],
    },
    "valentina": {
        "core": ("NÚCLEO BALÍSTICO COBALTO", "Unidad giroscópica de precisión balística y telemetría óptica de largo alcance de Valentina."),
        "speed": [
            ("REPLIEGUE TÁCTICO I", "+18% Velocidad de movimiento permanente en combate."),
            ("IMPULSO DE VANGUARDIA II", "+18% Velocidad de movimiento permanente (+36% acumulado)."),
            ("REPOSICIONAMIENTO HIPERSÓNICO", "+18% Velocidad (+54% acum.) y +20% aceleración de esquiva."),
        ],
        "damage": [
            ("PERFORACIÓN CINÉTICA I", "+18% Daño balístico y perforación de proyectil."),
            ("SABOT HIPER-VELOZ II", "+18% Daño balístico (+36% acum.) y +15% velocidad de proyectil."),
            ("IMPACTO ANTIMATERIAL", "+20% Daño balístico (+56% acum.) y penetración de armadura pesada."),
        ],
        "hp": [
            ("COMPUESTO DE KEVLAR I", "+25 Puntos de Salud Máxima permanente en combate."),
            ("CERÁMICA BALÍSTICA II", "+25 Puntos de Salud Máxima permanente (+50 HP acumulado)."),
            ("FORTALEZA TÁCTICA", "+30 Puntos de Salud Máxima (+80 HP acum.) y +2 Armadura base."),
        ],
        "crit": [
            ("MATRIZ ÓPTICA I", "+7% Probabilidad Crítica permanente en armas de largo alcance."),
            ("CALIBRACIÓN TÉRMICA II", "+7% Probabilidad Crítica (+14% acum.) y +20% Daño Crítico."),
            ("POD DE PUNTERÍA PRISMÁTICO", "+10% Prob. Crítica (+24% acum.) y fijación garantizada en el primer impacto."),
        ],
    },
    "roxy": {
        "core": ("REACTOR DE COMBUSTIÓN TITÁN", "Reactor de combustión termobárica pesada e ignición industrial de Roxy."),
        "speed": [
            ("EMBESTIDA BLINDADA I", "+16% Velocidad de movimiento permanente en combate."),
            ("POSTQUEMADOR DE ASALTO II", "+16% Velocidad de movimiento permanente (+32% acumulado)."),
            ("ASALTO JUGGERNAUT", "+18% Velocidad (+50% acum.) y daño de choque al colisionar."),
        ],
        "damage": [
            ("DISPERSIÓN TERMOBÁRICA I", "+20% Daño en salvas de dispersión y escopeta."),
            ("ESQUIRLAS INCENDIARIAS II", "+20% Daño (+40% acum.) y encendido por calor residual."),
            ("CAÑÓN DEVASTADOR FLAK", "+25% Daño (+65% acum.) y +20% tamaño de proyectil masivo."),
        ],
        "hp": [
            ("BLINDAJE CHOBHAM I", "+35 Puntos de Salud Máxima permanente en combate."),
            ("PLACAS REACTIVAS II", "+35 Puntos de Salud Máxima (+70 HP acum.) y +3 Armadura base."),
            ("MAMPARO DREADNOUGHT", "+40 Puntos de Salud Máxima (+110 HP acum.) y reducción de empuje."),
        ],
        "crit": [
            ("IMPACTO CONCUSIVO I", "+5% Probabilidad Crítica y +25% Daño Crítico."),
            ("MARTILLO HIDRÁULICO II", "+5% Probabilidad Crítica (+10% acum.) y +35% Daño Crítico."),
            ("DETONADOR DE RUPTURA", "+8% Probabilidad Crítica (+18% acum.) y ondas de choque explosivas."),
        ],
    },
    "selene": {
        "core": ("NÚCLEO SINGULAR DE GRAVITONES", "Micro-singularidad cósmica confinada que manipula la curvatura del espacio y la atracción de materia."),
        "speed": [
            ("PLIEGUE ESPACIAL I", "+18% Velocidad de movimiento permanente en combate."),
            ("CORRIENTE DE MAREA II", "+18% Velocidad de movimiento permanente (+36% acumulado)."),
            ("DESLIZAMIENTO DE GUSANO", "+18% Velocidad (+54% acum.) y atracción gravitacional al desplazarse."),
        ],
        "damage": [
            ("SIFÓN DE VACÍO I", "+16% Daño de energía cósmica y vórtices."),
            ("HORIZONTE DE SUCESOS II", "+16% Daño (+32% acum.) y compresión gravitatoria de enemigos."),
            ("COLAPSO DE MAREA", "+20% Daño (+52% acum.) con implosiones al eliminar objetivos."),
        ],
        "hp": [
            ("BARRERA GRAVITATORIA I", "+25 Puntos de Salud Máxima permanente en combate."),
            ("BURBUJA DE DISTORSIÓN II", "+25 Puntos de Salud Máxima (+50 HP acum.) y +30px Radio de Recogida."),
            ("MATRIZ HORIZONTE AEGIS", "+35 Puntos de Salud Máxima (+85 HP acum.) y desvío pasivo de proyectiles."),
        ],
        "crit": [
            ("ATRACCIÓN CELESTIAL I", "+6% Probabilidad Crítica y +40px Radio de Recogida."),
            ("POZO DE TRAYECTORIA II", "+6% Probabilidad Crítica (+12% acum.) y atracción de créditos."),
            ("PRISMA ASTROLÓGICO", "+10% Probabilidad Crítica (+22% acum.) y destellos estelares críticos."),
        ],
    },
    "echo": {
        "core": ("NÚCLEO VOLTAICO EMP", "Generador toroidal de alta tensión y condensadores superconductores de pulsos electromagnéticos."),
        "speed": [
            ("DESTELLO RELÁMPAGO I", "+22% Velocidad de movimiento permanente en combate."),
            ("CONDUCTOR IONIZADO II", "+22% Velocidad de movimiento permanente (+44% acumulado)."),
            ("RUSH HIPER-CONDUCTOR", "+22% Velocidad (+66% acum.) y rastro de micro-chispas al esquivar."),
        ],
        "damage": [
            ("ARCO TESLA I", "+15% Daño eléctrico y encadenamiento voltaico."),
            ("DESCARGA EN CADENA II", "+15% Daño (+30% acum.) y +1 objetivo extra en arcos voltaicos."),
            ("SOBRECARGA SISTÉMICA", "+20% Daño (+50% acum.) con detonaciones EMP al rematar aberraciones."),
        ],
        "hp": [
            ("BLINDAJE FARADAY I", "+20 Puntos de Salud Máxima permanente en combate."),
            ("MALLA AISLANTE II", "+20 Puntos de Salud Máxima (+40 HP acum.) y +10% Resistencia a daño."),
            ("BARRERA SUPERCONDUCTORA", "+30 Puntos de Salud Máxima (+70 HP acum.) y disipación de escudos."),
        ],
        "crit": [
            ("MATRIZ DE FRECUENCIA I", "+8% Cadencia de ataque y +4% Probabilidad Crítica."),
            ("BUCLE DE RESONANCIA II", "+8% Cadencia (+16% acum.) y +5% Probabilidad Crítica (+9% acum.)."),
            ("BOBINA SUPERCONDUCTORA", "+12% Cadencia (+28% acum.) y +8% Probabilidad Crítica (+17% acum.)."),
        ],
    },
    "kira": {
        "core": ("NÚCLEO DE COLMENA BIOMÓRFICA", "Matriz orgánica-cibernética de reproducción celular y control del enjambre de micro-nanobots."),
        "speed": [
            ("DESPRENDIMIENTO CELULAR I", "+18% Velocidad de movimiento permanente en combate."),
            ("PROPULSIÓN DE ESPORAS II", "+18% Velocidad de movimiento permanente (+36% acumulado)."),
            ("METAMORFOSIS DE ENJAMBRE", "+18% Velocidad (+54% acum.) y liberación de nanobots al acelerar."),
        ],
        "damage": [
            ("MICROMISILES BIO I", "+18% Daño de enjambres y proyectiles teledirigidos."),
            ("SALVA DE ENJAMBRE II", "+18% Daño (+36% acum.) y +1 proyectil teledirigido en salvas bio."),
            ("DEVASTADOR BIOMÓRFICO", "+22% Daño (+58% acum.) con ácido corrosivo en área de impacto."),
        ],
        "hp": [
            ("CAPARAZÓN DE QUITINA I", "+30 Puntos de Salud Máxima permanente en combate."),
            ("BIO-FILAMENTOS II", "+30 Puntos de Salud Máxima (+60 HP acum.) y +0.5 Regeneración de HP/s."),
            ("BALUARTE DE REINA", "+35 Puntos de Salud Máxima (+95 HP acum.) y capullo defensivo."),
        ],
        "crit": [
            ("MUTACIÓN DE ENJAMBRE I", "+6% Probabilidad Crítica y +15% Suerte permanente."),
            ("REPLICACIÓN AZAROSA II", "+6% Probabilidad Crítica (+12% acum.) y +15% Suerte (+30% acum.)."),
            ("BALIZA DE FEROMONAS", "+8% Probabilidad Crítica (+20% acum.) y golpes críticos que contagian nanobots."),
        ],
    },
}

def generate_tree_tres(pilot_id: str, data: dict):
    # Definición de nodos
    # 13 nodos: core, 3 speed, 3 damage, 3 hp, 3 crit
    nodes = [
        ("core", "NÚCLEO", data["core"][0], data["core"][1], POS_CORE, 0, "", "talent_core.png", "⚛"),
        ("speed_1", "VELOCIDAD", data["speed"][0][0], data["speed"][0][1], POS_SPEED_1, 25, "core", "talent_speed_1.png", "⚡"),
        ("speed_2", "VELOCIDAD", data["speed"][1][0], data["speed"][1][1], POS_SPEED_2, 25, "speed_1", "talent_speed_2.png", "⚡"),
        ("speed_3", "VELOCIDAD", data["speed"][2][0], data["speed"][2][1], POS_SPEED_3, 25, "speed_2", "talent_speed_3.png", "⚡"),
        ("damage_1", "DAÑO", data["damage"][0][0], data["damage"][0][1], POS_DMG_1, 25, "core", "talent_damage_1.png", "⚔"),
        ("damage_2", "DAÑO", data["damage"][1][0], data["damage"][1][1], POS_DMG_2, 25, "damage_1", "talent_damage_2.png", "⚔"),
        ("damage_3", "DAÑO", data["damage"][2][0], data["damage"][2][1], POS_DMG_3, 25, "damage_2", "talent_damage_3.png", "⚔"),
        ("hp_1", "SUPERVIVENCIA", data["hp"][0][0], data["hp"][0][1], POS_HP_1, 25, "core", "talent_hp_1.png", "🛡"),
        ("hp_2", "SUPERVIVENCIA", data["hp"][1][0], data["hp"][1][1], POS_HP_2, 25, "hp_1", "talent_hp_2.png", "🛡"),
        ("hp_3", "SUPERVIVENCIA", data["hp"][2][0], data["hp"][2][1], POS_HP_3, 25, "hp_2", "talent_hp_3.png", "🛡"),
        ("crit_1", "UTILIDAD", data["crit"][0][0], data["crit"][0][1], POS_CRIT_1, 25, "core", "talent_crit_1.png", "✦"),
        ("crit_2", "UTILIDAD", data["crit"][1][0], data["crit"][1][1], POS_CRIT_2, 25, "crit_1", "talent_crit_2.png", "✦"),
        ("crit_3", "UTILIDAD", data["crit"][2][0], data["crit"][2][1], POS_CRIT_3, 25, "crit_2", "talent_crit_3.png", "✦"),
    ]

    # For Nyx, maintain nyx_ prefix if desired, or standardize. Let's keep nyx_ if needed:
    if pilot_id == "nyx":
        nodes = [
            ("core", "NÚCLEO", data["core"][0], data["core"][1], POS_CORE, 0, "", "talent_core.png", "⚛"),
            ("nyx_speed_1", "PASO UMBRÍO", data["speed"][0][0], data["speed"][0][1], POS_SPEED_1, 25, "core", "talent_speed_1.png", "⚡"),
            ("nyx_speed_2", "PASO UMBRÍO", data["speed"][1][0], data["speed"][1][1], POS_SPEED_2, 25, "nyx_speed_1", "talent_speed_2.png", "⚡"),
            ("nyx_speed_3", "PASO UMBRÍO", data["speed"][2][0], data["speed"][2][1], POS_SPEED_3, 25, "nyx_speed_2", "talent_speed_3.png", "⚡"),
            ("nyx_dmg_1", "FILO DIMENSIONAL", data["damage"][0][0], data["damage"][0][1], POS_DMG_1, 25, "core", "talent_damage_1.png", "⚔"),
            ("nyx_dmg_2", "FILO DIMENSIONAL", data["damage"][1][0], data["damage"][1][1], POS_DMG_2, 25, "nyx_dmg_1", "talent_damage_2.png", "⚔"),
            ("nyx_dmg_3", "FILO DIMENSIONAL", data["damage"][2][0], data["damage"][2][1], POS_DMG_3, 25, "nyx_dmg_2", "talent_damage_3.png", "⚔"),
            ("nyx_hp_1", "MANTO CREPUSCULAR", data["hp"][0][0], data["hp"][0][1], POS_HP_1, 25, "core", "talent_hp_1.png", "🛡"),
            ("nyx_hp_2", "MANTO CREPUSCULAR", data["hp"][1][0], data["hp"][1][1], POS_HP_2, 25, "nyx_hp_1", "talent_hp_2.png", "🛡"),
            ("nyx_hp_3", "MANTO CREPUSCULAR", data["hp"][2][0], data["hp"][2][1], POS_HP_3, 25, "nyx_hp_2", "talent_hp_3.png", "🛡"),
            ("nyx_crit_1", "FURIA DE MEDIALUNA", data["crit"][0][0], data["crit"][0][1], POS_CRIT_1, 25, "core", "talent_crit_1.png", "✦"),
            ("nyx_crit_2", "FURIA DE MEDIALUNA", data["crit"][1][0], data["crit"][1][1], POS_CRIT_2, 25, "nyx_crit_1", "talent_crit_2.png", "✦"),
            ("nyx_crit_3", "FURIA DE MEDIALUNA", data["crit"][2][0], data["crit"][2][1], POS_CRIT_3, 25, "nyx_crit_2", "talent_crit_3.png", "✦"),
        ]

    lines = [
        '[gd_resource type="Resource" script_class="SkillTreeConfig" format=3]',
        '',
        '[ext_resource type="Script" path="res://core/types/skill_tree_node_data.gd" id="1_node_script"]',
        '[ext_resource type="Script" path="res://core/types/skill_tree_config.gd" id="2_config_script"]',
    ]

    # Texture2D ExtResources
    for idx, node in enumerate(nodes):
        ico_id = f"ico_{idx+1}"
        ico_path = f"res://assets/characters/talents/{pilot_id}/{node[7]}"
        lines.append(f'[ext_resource type="Texture2D" path="{ico_path}" id="{ico_id}"]')

    lines.append('')

    # Sub resources
    sub_res_ids = []
    for idx, (nid, branch, title, desc, pos, cost, req, ico_file, glyph) in enumerate(nodes):
        sub_id = f"Resource_{idx+1}"
        sub_res_ids.append(sub_id)
        ico_id = f"ico_{idx+1}"
        lines.append(f'[sub_resource type="Resource" id="{sub_id}"]')
        lines.append('script = ExtResource("1_node_script")')
        lines.append(f'id = &"{nid}"')
        lines.append(f'branch = "{branch}"')
        lines.append(f'title = "{title}"')
        lines.append(f'description = "{desc}"')
        lines.append(f'icon = ExtResource("{ico_id}")')
        lines.append(f'glyph = "{glyph}"')
        lines.append(f'position = {pos}')
        lines.append(f'cost = {cost}')
        lines.append(f'req_id = &"{req}"')
        lines.append('')

    # Root resource
    lines.append('[resource]')
    lines.append('script = ExtResource("2_config_script")')
    lines.append(f'character_id = &"{pilot_id}"')
    lines.append('node_cost = 25')
    lines.append('nodes = Array[Resource]([')
    for s_id in sub_res_ids:
        lines.append(f'SubResource("{s_id}"),')
    lines.append('])')
    lines.append('')

    filename = f"skill_tree_{pilot_id}.tres"
    out_path = os.path.join(OUTPUT_DIR, filename)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"OK: Generado {filename} con {len(nodes)} nodos e iconos vinculados")

def main():
    for pilot_id, data in PILOTS_DATA.items():
        generate_tree_tres(pilot_id, data)

    # También actualizar skill_tree_default.tres basado en Nova
    generate_tree_tres("default", PILOTS_DATA["nova"])

if __name__ == "__main__":
    main()
