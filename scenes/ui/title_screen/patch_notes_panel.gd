class_name PatchNotesPanel
extends PanelContainer

## PatchNotesPanel.gd
## Panel integrado siempre visible en la pantalla de inicio con las notas de la versión.
## Soporta carga instantánea local y actualización asíncrona desde GitHub origin/master.

@onready var status_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/StatusLabel
@onready var notes_text: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/NotesText
@onready var http_request: HTTPRequest = $HTTPRequest

const GITHUB_README_URL := "https://raw.githubusercontent.com/Ftleyell/astra-dream/master/README.md"
const LOCAL_NOTES_PATH := "res://data/patch_notes_local.txt"

var _is_fetching: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	if http_request:
		http_request.request_completed.connect(_on_http_request_completed)

	_load_local_notes()
	_fetch_remote_notes()


func _load_local_notes() -> void:
	if FileAccess.file_exists(LOCAL_NOTES_PATH):
		var fa := FileAccess.open(LOCAL_NOTES_PATH, FileAccess.READ)
		if fa:
			var content := fa.get_as_text()
			fa.close()
			if notes_text:
				notes_text.text = content
			if status_label:
				status_label.text = "● Notas Locales (v0.4.0)"
				status_label.modulate = Color(0.22, 0.74, 0.97, 1.0)
			return

	if notes_text:
		notes_text.text = "[b][color=#00f0ff]ASTRA DREAM // NOTAS DEL PARCHE[/color][/b]\nRegistro de versiones disponible en el repositorio de GitHub."


func _fetch_remote_notes() -> void:
	if _is_fetching or not http_request:
		return

	_is_fetching = true
	if status_label:
		status_label.text = "● Sincronizando con GitHub..."
		status_label.modulate = Color(1.0, 0.8, 0.2, 1.0)

	var err := http_request.request(GITHUB_README_URL)
	if err != OK:
		_is_fetching = false
		if status_label:
			status_label.text = "● Modo Local"
			status_label.modulate = Color(0.7, 0.7, 0.7, 0.8)


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_fetching = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var raw_md := body.get_string_from_utf8()
		var parsed_bbcode := _parse_patch_notes_from_readme(raw_md)
		if not parsed_bbcode.is_empty():
			if notes_text:
				notes_text.text = parsed_bbcode
			if status_label:
				status_label.text = "● Conectado a GitHub (Master)"
				status_label.modulate = Color(0.22, 0.94, 0.49, 1.0)
			return

	if status_label:
		status_label.text = "● Modo Local (Offline)"
		status_label.modulate = Color(0.6, 0.7, 0.8, 0.8)


func _parse_patch_notes_from_readme(markdown: String) -> String:
	var start_idx := markdown.find("## 📝 Notas del Parche")
	if start_idx == -1:
		start_idx = markdown.find("Notas del Parche")
	if start_idx == -1:
		return ""

	var end_idx := markdown.find("\n## ", start_idx + 10)
	var section := markdown.substr(start_idx, (end_idx - start_idx) if end_idx != -1 else -1)

	var bbcode := section
	bbcode = bbcode.replace("## 📝 Notas del Parche / Registro de Actualizaciones (v0.4.0 - Master)", "[b][color=#00f0ff]ASTRA DREAM — NOTAS DEL PARCHE (v0.4.0 - Master)[/color][/b]\n[color=#70a1ff]Sincronizado en tiempo real desde GitHub origin/master[/color]\n")
	bbcode = bbcode.replace("### 🚀 Últimas Novedades y Sistemas Implementados", "")
	bbcode = bbcode.replace("#### 🎯 Armamento Balístico Autónomo (Capa Pasiva Rediseñada)", "\n[b][color=#ffeaa7]━━━ 🎯 ARMAMENTO BALÍSTICO AUTÓNOMO (CAPA PASIVA) ━━━[/color][/b]")
	bbcode = bbcode.replace("#### ⚡ Maniobras Evasivas Avanzadas (Dashes Únicos por Heroína)", "\n[b][color=#ffeaa7]━━━ ⚡ MANIOBRAS EVASIVAS AVANZADAS (DASHES ÚNICOS) ━━━[/color][/b]")
	bbcode = bbcode.replace("#### 🌌 Hangar Estelar 3D & Mirador Panorámico", "\n[b][color=#ffeaa7]━━━ 🌌 HANGAR ESTELAR 3D & MIRADOR PANORÁMICO ━━━[/color][/b]")
	bbcode = bbcode.replace("#### 📡 Radar Perimétrico Orbital & HUD Táctico", "\n[b][color=#ffeaa7]━━━ 📡 RADAR PERIMÉTRICO ORBITAL & HUD TÁCTICO ━━━[/color][/b]")

	var regex := RegEx.new()
	regex.compile("\\*\\*(.*?)\\*\\*")
	bbcode = regex.sub(bbcode, "[b]$1[/b]", true)

	return bbcode
