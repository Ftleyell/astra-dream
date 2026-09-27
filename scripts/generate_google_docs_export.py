import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=140, bottom=140, left=200, right=200):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(
        f'<w:tcMar {nsdecls("w")}>'
        f'<w:top w:w="{top}" w:type="dxa"/>'
        f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
        f'<w:left w:w="{left}" w:type="dxa"/>'
        f'<w:right w:w="{right}" w:type="dxa"/>'
        f'</w:tcMar>'
    )
    tcPr.append(tcMar)

def set_cell_border(cell, **kwargs):
    """
    kwargs can be top, bottom, left, right.
    val: 'single', 'double', 'dashed', etc.
    color: '003366', 'CCCCCC', etc.
    sz: '4', '8', '12', etc. (eighths of a pt)
    """
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = parse_xml(f'<w:tcBorders {nsdecls("w")}/>')
    for edge, border_args in kwargs.items():
        val = border_args.get('val', 'single')
        color = border_args.get('color', 'CCCCCC')
        sz = border_args.get('sz', '4')
        border_xml = parse_xml(f'<w:{edge} {nsdecls("w")} w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>')
        tcBorders.append(border_xml)
    tcPr.append(tcBorders)

def create_callout(doc, text_content, title=None, border_color="008080", bg_color="F0F9FF"):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    table.columns[0].width = Inches(6.5)
    
    cell = table.cell(0, 0)
    set_cell_background(cell, bg_color)
    set_cell_margins(cell, top=160, bottom=160, left=240, right=200)
    set_cell_border(cell, 
                    left={'val': 'single', 'color': border_color, 'sz': '24'},
                    top={'val': 'none'}, right={'val': 'none'}, bottom={'val': 'none'})
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.15
    
    if title:
        run_title = p.add_run(f"{title}\n")
        run_title.bold = True
        run_title.font.name = "Arial"
        run_title.font.size = Pt(10.5)
        run_title.font.color.rgb = RGBColor(0x00, 0x4D, 0x66)
        
    run_text = p.add_run(text_content)
    run_text.font.name = "Arial"
    run_text.font.size = Pt(10)
    run_text.font.color.rgb = RGBColor(0x22, 0x22, 0x22)
    
    # Add space after table
    p_after = doc.add_paragraph()
    p_after.paragraph_format.space_before = Pt(4)
    p_after.paragraph_format.space_after = Pt(6)

def add_heading_styled(doc, text, level):
    h = doc.add_heading(text, level=level)
    h.paragraph_format.keep_with_next = True
    for r in h.runs:
        r.font.name = "Arial"
    if level == 1:
        h.paragraph_format.space_before = Pt(18)
        h.paragraph_format.space_after = Pt(8)
        for r in h.runs:
            r.font.size = Pt(16)
            r.bold = True
            r.font.color.rgb = RGBColor(0x0F, 0x38, 0x60) # Deep Navy
    elif level == 2:
        h.paragraph_format.space_before = Pt(14)
        h.paragraph_format.space_after = Pt(6)
        for r in h.runs:
            r.font.size = Pt(13)
            r.bold = True
            r.font.color.rgb = RGBColor(0x1B, 0x6E, 0x8C) # Teal Blue
    elif level == 3:
        h.paragraph_format.space_before = Pt(10)
        h.paragraph_format.space_after = Pt(4)
        for r in h.runs:
            r.font.size = Pt(11)
            r.bold = True
            r.font.color.rgb = RGBColor(0x4A, 0x25, 0x74) # Deep Purple
    return h

def add_styled_paragraph(doc, text, bold_prefix=None, space_after=6):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing = 1.15
    if bold_prefix:
        r_pre = p.add_run(bold_prefix)
        r_pre.bold = True
        r_pre.font.name = "Arial"
        r_pre.font.size = Pt(10.5)
        r_pre.font.color.rgb = RGBColor(0x11, 0x18, 0x27)
    r_text = p.add_run(text)
    r_text.font.name = "Arial"
    r_text.font.size = Pt(10.5)
    r_text.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    return p

def add_bullet_point(doc, bold_title, description):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    
    r_title = p.add_run(bold_title + " ")
    r_title.bold = True
    r_title.font.name = "Arial"
    r_title.font.size = Pt(10)
    r_title.font.color.rgb = RGBColor(0x0F, 0x38, 0x60)
    
    r_desc = p.add_run(description)
    r_desc.font.name = "Arial"
    r_desc.font.size = Pt(10)
    r_desc.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    return p

def build_docx(output_path):
    doc = Document()
    
    # Page Margins: 1 inch
    for section in doc.sections:
        section.top_margin = Inches(0.9)
        section.bottom_margin = Inches(0.9)
        section.left_margin = Inches(0.9)
        section.right_margin = Inches(0.9)
    
    # Set default style font
    style = doc.styles['Normal']
    font = style.font
    font.name = 'Arial'
    font.size = Pt(10.5)
    font.color.rgb = RGBColor(0x2D, 0x37, 0x48)

    # DOCUMENT TITLE / COVER BANNER
    title_table = doc.add_table(rows=1, cols=1)
    title_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    title_table.autofit = False
    title_table.columns[0].width = Inches(6.7)
    
    title_cell = title_table.cell(0, 0)
    set_cell_background(title_cell, "0F2537") # Dark Navy Blue
    set_cell_margins(title_cell, top=280, bottom=280, left=320, right=320)
    
    p_tag = title_cell.paragraphs[0]
    p_tag.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r_tag = p_tag.add_run("ASTRA DREAM • DOCUMENTO MAESTRO DE DISEÑO")
    r_tag.bold = True
    r_tag.font.name = "Arial"
    r_tag.font.size = Pt(9.5)
    r_tag.font.color.rgb = RGBColor(0x38, 0xBD, 0xF8) # Bright Cyan
    
    p_main = title_cell.add_paragraph()
    p_main.paragraph_format.space_before = Pt(6)
    p_main.paragraph_format.space_after = Pt(8)
    r_main = p_main.add_run("🎨 GUÍA MAESTRA CREATIVA:\nESTÉTICA, NARRATIVA DIVERGENTE Y UNIVERSO AUDIOVISUAL")
    r_main.bold = True
    r_main.font.name = "Arial"
    r_main.font.size = Pt(18)
    r_main.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    
    p_meta = title_cell.add_paragraph()
    p_meta.paragraph_format.space_before = Pt(4)
    r_meta = p_meta.add_run("Destinatarios: Artista Principal, Diseñador Narrativo, Artista de UI/Entornos y Compositor de Audio\nPropósito: Libertad Creativa Total + Integración Sistémica del Motor de Juego")
    r_meta.font.name = "Arial"
    r_meta.font.size = Pt(9.5)
    r_meta.font.color.rgb = RGBColor(0xCB, 0xD5, 0xE1)
    
    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    # 1. MANIFIESTO
    add_heading_styled(doc, "🧭 1. Manifiesto y Visión: Libertad Creativa con Anclaje Sistémico", level=1)
    add_styled_paragraph(doc, "Este documento corona y sintetiza la serie de especificaciones del proyecto. Tu rol no es simplemente 'dibujar sprites o componer pistas sueltas', sino definir el alma, el tono, la identidad sensorial y la emoción de todo el universo de Astra Dream.")
    
    create_callout(
        doc,
        "• TU ESPACIO LIBRE: Tienes total autonomía para definir el estilo visual (Anime Mecha-Musume / Sci-Fi / Cyberpunk), los shaders, la arquitectura del Hangar 2.5D, la paleta cromática, el género musical (Synthwave, Dark Synth, Metal Orquestal) y la personalidad de las pilotos.\n\n"
        "• EL MOTOR Y SISTEMAS: El gameplay loop de 360°, el sistema de Satélites, el motor de diálogos Dialogic 2, el sistema de perdón/combate de Pilotos Rivales y la meta-progresión son las anclas sólidas sobre las que se apoya tu arte.",
        title="🌟 ALCANCE DE LA LIBERTAD CREATIVA",
        border_color="0284C7",
        bg_color="F0F9FF"
    )

    # 2. ANATOMIA DEL PRODUCTO
    add_heading_styled(doc, "🔄 2. Anatomía del Producto: El Gameplay Loop Integral", level=1)
    add_styled_paragraph(doc, "Para que cada ilustración, shader, acorde musical y efecto de sonido encaje con precisión, este es el flujo de juego que experimenta el jugador:")
    
    # Table of Gameplay Loop
    loop_table = doc.add_table(rows=6, cols=3)
    loop_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    loop_table.autofit = False
    
    col_widths = [Inches(1.8), Inches(2.4), Inches(2.5)]
    for row in loop_table.rows:
        for i, width in enumerate(col_widths):
            row.cells[i].width = width
            
    headers = ["Fase del Juego", "Qué ocurre en el Motor", "Oportunidad Artística / Audio"]
    for i, h_text in enumerate(headers):
        cell = loop_table.cell(0, i)
        set_cell_background(cell, "0F3860")
        set_cell_margins(cell, top=140, bottom=140, left=140, right=140)
        p = cell.paragraphs[0]
        r = p.add_run(h_text)
        r.bold = True
        r.font.name = "Arial"
        r.font.size = Pt(9.5)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        
    phases_data = [
        ("1. Hangar / Hub 2.5D", "Menús de selección, customización de trajes, árbol de talentos, interacción social con heroínas, navegadoras y pets.", "Ilustraciones full body sensuales/carismáticas (Hub Outfits), entorno 2.5D con parallax, música Lo-Fi / Synth ambient relajante."),
        ("2. In-Run (Vuelo 360°)", "Movimiento inercial, recolección de cristales, oleadas crecientes, captura de satélites baliza.", "Sprites de combate Mecha-Musume con propulsores reactivos, BGM dinámico por capas (Stems) que acelera con el peligro."),
        ("3. Encuentro con Rival (Oleadas 1,3,5,7,9)", "Aparece una piloto real en radar con anillo de advertencia (650px). Decisión moral: paz o duelo.", "Retrato de transmisión con glitch/estática, BGM silencia la música y entra el Stinger/Leitmotif personal de la Rival."),
        ("4. Clímax: Boss Titán", "Jefes monumentales con múltiples fases, barras de vida segmentadas y proyectiles geométricos.", "Escala colosal, distorsión de pantalla (Chromatic Aberration), BGM épico de Dark Synth con percusión orquestal pesada."),
        ("5. Desenlace y Epílogo", "Pantalla de victoria/derrota, cálculo de recompensas, diálogos de balance y epílogo según moral.", "Ilustraciones CG de recompensa, epílogos desbloqueables en Dialogic, pista de resolución emotiva o triunfal.")
    ]
    
    for row_idx, data in enumerate(phases_data, start=1):
        bg = "FFFFFF" if row_idx % 2 != 0 else "F8FAFC"
        for col_idx, text in enumerate(data):
            cell = loop_table.cell(row_idx, col_idx)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=120, bottom=120, left=140, right=140)
            set_cell_border(cell, 
                            top={'val': 'single', 'color': 'E2E8F0', 'sz': '4'},
                            bottom={'val': 'single', 'color': 'E2E8F0', 'sz': '4'})
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.15
            r = p.add_run(text)
            r.font.name = "Arial"
            r.font.size = Pt(9)
            if col_idx == 0:
                r.bold = True
                r.font.color.rgb = RGBColor(0x0F, 0x38, 0x60)
            else:
                r.font.color.rgb = RGBColor(0x33, 0x41, 0x55)
                
    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # 3. HANGAR / HUB 2.5D
    add_heading_styled(doc, "🏢 3. El Hangar / Hub 2.5D: El Hogar de las Heroínas", level=1)
    add_styled_paragraph(doc, "El Hangar no es un simple menú estático; es un entorno con perspectiva 2.5D y profundidad de capas Parallax donde las heroínas conviven, se preparan e interactúan entre misiones.")
    
    add_bullet_point(doc, "Plataformas y Profundidad Parallax:", "Fondo lejano con grandes ventanales hacia nebulosas y el cosmos; plano medio con brazos robóticos y naves en mantenimiento; primer plano interactivo donde descansan y caminan los personajes.")
    add_bullet_point(doc, "Atuendos Informales ('Hub Outfits'):", "Oportunidad de mostrar a las pilotos con ropa casual, elegante o deportiva táctica de descanso, contrastando con la pesada exo-armadura de combate en vuelo.")
    add_bullet_point(doc, "Muelle de Lanzamiento:", "Terminal central para seleccionar heroína, cambiar paleta de skins y armas principales.")
    add_bullet_point(doc, "Puente de Navegación:", "Estación táctica para consultar sectores espaciales y elegir a la Navegadora activa.")
    add_bullet_point(doc, "Guardería de Pets:", "Espacio acogedor donde las mascotas cósmicas duermen, juegan y reciben mejoras de vínculo.")
    add_bullet_point(doc, "Matriz de Talentos:", "Núcleo holográfico para desbloquear upgrades pasivos permanentes.")
    add_bullet_point(doc, "Salón de Trofeos & Holo-Museo:", "Vitrina de memorabilia de rivales, núcleos de jefes vencidos y Jukebox musical.")

    # 4. PETS
    add_heading_styled(doc, "🐾 4. Sistema de Pets (Mascotas de Compañía)", level=1)
    add_styled_paragraph(doc, "Los Pets son pequeños compañeros biomecánicos o criaturas astrales (sprites 64x64) que orbitan a la heroína en combate y ofrecen auras y apoyo moral.")
    
    add_bullet_point(doc, "Comportamiento y Reacciones In-Run:", "Flotan con inercia elástica siguiendo al jugador. Tienen animaciones de alegría en multi-kills, pánico/encogimiento durante ataques pesados de jefes, y alertas al detectar balizas de satélite.")
    add_bullet_point(doc, "Presencia Narrativa en Dialogic:", "Intervienen con ladridos electrónicos, chillidos tiernos o emoticonos en pantalla para agregar calidez y humor a los diálogos de cabina.")
    add_bullet_point(doc, "Los 5 Arquetipos Base:", "Pip (Dron esférico curioso con pantalla LED emocional), Cosmo (Gato cósmico con cola de plasma), Luna (Zorro espectral con pelaje de polvo de estrellas), Kuro (Dragón cibernético que escupe chispas) y Mochi (Gelatina astral biomorfa y tierna).")

    # 5. NAVEGADORAS
    add_heading_styled(doc, "👩‍✈️ 5. Sistema de Navegadoras: Las Voces del Control Táctico", level=1)
    add_styled_paragraph(doc, "Las Navegadoras operan desde el puente de la estación espacial. Proporcionan inteligencia militar, auras pasivas globales y comentarios tácticos en tiempo real.")
    
    add_bullet_point(doc, "Bustos Circulares en HUD Radio:", "Retratos de alta resolución enmarcados en burbujas con estados emocionales (Neutra, Alerta de Peligro, Festejo de Victoria, Pánico y Confiada).")
    add_bullet_point(doc, "Identidad y Personalidades:", "Iris (Estratega militar fría y calculadora), Zephyr (Piloto veterana y relajada con actitud rebelde), Caelia (Científica e inventora excéntrica), Vespera (Operadora enigmática de operaciones clandestinas) y Lyra (Idol cósmica y animadora pop espacial).")
    add_bullet_point(doc, "Efectos de Audio de Transmisión:", "Filtro paso-altos (Walkie-Talkie Sci-Fi), ruidos de estática y bleeps tácticos distintivos para cada una.")

    # 6. ARBOL DE TALENTOS
    add_heading_styled(doc, "🧬 6. Árbol de Talentos y Meta-Progresión (Matriz de Habilidades)", level=1)
    add_styled_paragraph(doc, "El progreso permanente entre partidas se visualiza como un circuito holográfico o constelación tecnológica interconectada en el Hangar:")
    
    add_bullet_point(doc, "Rama Ofensiva (Plasma & Balística):", "Aumentos de daño base, velocidad de proyectiles, cadencia y probabilidad de daño crítico.")
    add_bullet_point(doc, "Rama Defensiva (Baluarte & Nanites):", "Capacidad máxima de escudos, velocidad de regeneración y reducción de daño a la armadura.")
    add_bullet_point(doc, "Rama de Movilidad (Propulsión & Overclock):", "Enfriamiento del Dash sónico, aceleración de giro 360° y duración de invulnerabilidad (I-Frames).")
    add_bullet_point(doc, "Rama de Ingeniería (Salvamento & Detección):", "Aumento del radio de atracción magnética de gemas de XP, rerolls de satélites y bonificación de créditos estelares.")
    add_bullet_point(doc, "Nodos Maestros (Keystones):", "Habilidades cumbre con emblemas animados brillantes y un sonido pesado de acople industrial al desbloquearse.")

    # 7. TROFEOS Y MUSEO
    add_heading_styled(doc, "🏆 7. Salón de Trofeos, Logros y Holo-Museo", level=1)
    add_styled_paragraph(doc, "Espacio de coleccionismo y gloria para recompensar la maestría del jugador:")
    
    add_bullet_point(doc, "Memorabilia de Rivales:", "Vitrinas con las armas insignia de las rivales vencidas o las medallas de pacto de aquellas a las que perdonaste la vida.")
    add_bullet_point(doc, "Núcleos de Jefes Titanes:", "Esferas gravitacionales giratorias que contienen la energía de los jefes de sector eliminados.")
    add_bullet_point(doc, "Galería CG y Jukebox:", "Visualizador de ilustraciones cinematográficas de los finales y reproductor de la banda sonora completa.")

    # 8. UI Y HUD
    add_heading_styled(doc, "🖥️ 8. Interfaz de Usuario (UI / HUD) y Coherencia Estética", level=1)
    add_styled_paragraph(doc, "La interfaz equilibra la máxima legibilidad durante el bullet-hell con una estética futurista refinada:")
    
    add_bullet_point(doc, "HUD In-Run (Minimalismo Funcional):", "Arcos de vida y escudo curvos o barras compactas; brújula perimetral con iconos hacia balizas de satélite y rivales; burbujas de radio no invasivas.")
    add_bullet_point(doc, "UI de Hangar (Diegética & Glassmorphism):", "Paneles translúcidos con reflejos de luz, bordes neón brillantes (cian, magenta, oro) y tipografía limpia.")
    add_bullet_point(doc, "Micro-Interacciones y Sonido:", "Clicks capacitivos suaves al pasar el cursor (hover), golpes metálicos precisos al confirmar y zumbidos holográficos al abrir menús.")

    # 9. INTEGRACION CON DIALOGIC
    add_heading_styled(doc, "🎭 9. Integración con Dialogic: El Alma de las Interacciones", level=1)
    add_styled_paragraph(doc, "El motor Dialogic 2 permite una narrativa ágil y fluida sin frenar la adrenalina arcade:")
    
    create_callout(
        doc,
        "1. BURBUJAS DE RADIO IN-RUN: Retratos circulares animados en los laterales de la pantalla con avisos rápidos (satélite listo, alerta de misiles, advertencias de rivales).\n\n"
        "2. INTERLUDIOS DE CABINA: Pausa de 5-10 segundos entre oleadas para que la piloto converse con su navegadora o mascota sobre la misión.\n\n"
        "3. ESCENAS DE NOVELA VISUAL EN EL HUB: Retratos de cuerpo entero con poses expresivas (neutra, furiosa, herida, sonrojada, triunfal) para diálogos profundos y epílogos.",
        title="💬 LOS 3 CANALES DE DIÁLOGO EN GODOT",
        border_color="7C3AED",
        bg_color="FAF5FF"
    )

    # 10. PILOTOS RIVALES
    add_heading_styled(doc, "⚔️ 10. Sistema de Pilotos Rivales: El Motor de Ramificación Narrativa", level=1)
    add_styled_paragraph(doc, "En las oleadas impares (1, 3, 5, 7, 9) pueden aparecer Pilotos Rivales. El jugador tiene el control absoluto de su destino moral:")
    
    create_callout(
        doc,
        "🕊️ CAMINO DEL PERDÓN (SPARE):\n"
        "Si el jugador se aleja (>1400px durante 4 segundos), la rival reconoce el gesto honorable y se retira pacíficamente. Al perdonar a las 5 rivales, estas aparecen en el combate final como ALAS ALIADAS en el Final Verdadero ('Pacto Estelar').\n\n"
        "⚔️ CAMINO DE LA ANIQUILACIÓN (KILL):\n"
        "Si el jugador ataca o invade su espacio (<340px), se desata un duelo aéreo 1v1 a muerte. Vencerla otorga su arma insignia, pero acumula rencor y conduce al Final Oscuro ('Soberana del Vacío').\n\n"
        "⚖️ FINALES DE FACCIÓN (MIXTOS):\n"
        "Perdonar a unas rivales y destruir a otras genera alianzas parciales, traiciones y desenlaces narrativos únicos.",
        title="🌟 RAMIFICACIONES Y FINALES DIVERGENTES",
        border_color="D97706",
        bg_color="FFFBEB"
    )

    # 11. AUDIO & BGM
    add_heading_styled(doc, "🎧 11. Arquitectura y Dirección de Audio & Música", level=1)
    add_styled_paragraph(doc, "El sistema AudioManager de Godot está preparado para música adaptativa y efectos con alto impacto táctil:")
    
    add_bullet_point(doc, "BGM Dinámico por Capas (Stems):", "La música añade pistas de percusión y sintetizadores según la intensidad de la oleada.")
    add_bullet_point(doc, "Stingers y Leitmotifs de Rivales:", "Cada piloto rival silencia el tema general e introduce su propio solo/riff de guitarra o sintetizador insignia al entrar en radio.")
    add_bullet_point(doc, "Sonido de Gemas y Recompensas:", "Tintineo cristalino en escala ascendente que genera gran satisfacción al aspirar enjambres de cristales.")
    add_bullet_point(doc, "Telegrafiado Acústico de Peligro:", "Pitidos de advertencia 0.8s antes de rayos lásers titánicos o salvas de misiles.")

    # 12. MATRIZ DE ENTREGABLES
    add_heading_styled(doc, "📋 12. Matriz de Entregables para el Equipo Creativo", level=1)
    
    deliv_table = doc.add_table(rows=11, cols=3)
    deliv_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    deliv_table.autofit = False
    
    deliv_widths = [Inches(1.8), Inches(2.2), Inches(2.7)]
    for row in deliv_table.rows:
        for i, width in enumerate(deliv_widths):
            row.cells[i].width = width
            
    deliv_headers = ["Categoría", "Entregable Clave", "Especificación Sugerida"]
    for i, h_text in enumerate(deliv_headers):
        cell = deliv_table.cell(0, i)
        set_cell_background(cell, "0F3860")
        set_cell_margins(cell, top=140, bottom=140, left=140, right=140)
        p = cell.paragraphs[0]
        r = p.add_run(h_text)
        r.bold = True
        r.font.name = "Arial"
        r.font.size = Pt(9.5)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        
    deliverables_data = [
        ("Heroínas (Hub)", "6 Base + 1 Desbloqueable (Nyx)", "Ilustraciones full-body 1080p+ con atuendos casuales/sensuales y expresiones."),
        ("Heroínas (In-Run)", "Sprites Mecha-Musume", "Spritesheets 360°/Direccionales (128x128 o 256x256) con propulsores reactivos."),
        ("Hangar / Hub 2.5D", "Fondos y Estaciones", "Capas Parallax independientes (Fondo, Medio, Frente) a 1920x1080."),
        ("Navegadoras & Pets", "5 Navegadoras + 5 Pets", "Navegadoras: Retratos circulares HUD. Pets: Sprites flotantes 64x64 animados."),
        ("Árbol de Talentos & UI", "Iconos y Paneles", "Iconos vector/pixel 64x64 + paneles modulares de estilo Glassmorphism."),
        ("Salón de Trofeos", "Memorabilia y Cores", "Sprites/Modelos 128x128 con efectos de brillo y pedestales."),
        ("Pilotos Rivales", "Mechas y Retratos", "Retratos de radio (normal, hostil, herida, respeto) + mechas personalizados."),
        ("Ítems & Satélites", "12 Stats + Balizas", "Iconos 64x64 con código de color unificado por atributo."),
        ("Enemigos & Jefes", "6 Arquetipos + 3 Titanes", "Puntos débiles luminosos, fases de daño y animaciones de telegrafiado."),
        ("BGM & SFX Packs", "Soundtrack y Sonidos", "Música: OGG seamless loop + Stems. SFX: WAV sin pérdida 44.1kHz / 24-bit.")
    ]
    
    for row_idx, data in enumerate(deliverables_data, start=1):
        bg = "FFFFFF" if row_idx % 2 != 0 else "F8FAFC"
        for col_idx, text in enumerate(data):
            cell = deliv_table.cell(row_idx, col_idx)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=100, bottom=100, left=140, right=140)
            set_cell_border(cell, 
                            top={'val': 'single', 'color': 'E2E8F0', 'sz': '4'},
                            bottom={'val': 'single', 'color': 'E2E8F0', 'sz': '4'})
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.15
            r = p.add_run(text)
            r.font.name = "Arial"
            r.font.size = Pt(8.5)
            if col_idx == 0:
                r.bold = True
                r.font.color.rgb = RGBColor(0x0F, 0x38, 0x60)
            else:
                r.font.color.rgb = RGBColor(0x33, 0x41, 0x55)
                
    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    # 13. CONCLUSION
    add_heading_styled(doc, "🌟 13. Conclusión: El Universo es Tuyo", level=1)
    add_styled_paragraph(doc, "El motor está listo, los proyectiles vuelan fluidos a 60 FPS, los satélites orbitan, el hangar espera ser habitado y las pilotos aguardan su voz, su aspecto y su música. Tienes las riendas para plasmar una estética inolvidable que convierta a Astra Dream en una joya de culto tanto visual como auditiva y narrativa.")

    doc.save(output_path)
    print(f"Successfully generated DOCX at: {output_path}")

if __name__ == "__main__":
    out_dir = r"C:\Users\Frani\.gemini\antigravity\scratch\astra_dream\docs\art"
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, "Astra_Dream_Guia_Maestra_Creativa.docx")
    build_docx(out_file)
