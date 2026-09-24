class_name PatchNotesModal
extends CanvasLayer

signal closed()

@onready var panel_container: PanelContainer = $Backdrop/PanelContainer
@onready var status_label: Label = $Backdrop/PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/StatusLabel
@onready var notes_text: RichTextLabel = $Backdrop/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/NotesText
@onready var close_button: Button = $Backdrop/PanelContainer/MarginContainer/VBoxContainer/BottomBar/CloseButton
@onready var http_request: HTTPRequest = $HTTPRequest

const GITHUB_README_URL := "https://raw.githubusercontent.com/Ftleyell/astra-dream/master/README.md"
const LOCAL_NOTES_PATH := "res://data/patch_notes_local.txt"

var _is_loaded: bool = false
var _is_fetching: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	hide()

	if close_button:
		close_button.pressed.connect(close_modal)

	if http_request:
		http_request.request_completed.connect(_on_http_request_completed)

	_load_local_notes()


func open_modal() -> void:
	show()
	if not _is_loaded:
		_load_local_notes()

	_fetch_remote_notes()

	if close_button:
		close_button.grab_focus()


func close_modal() -> void:
	hide()
	closed.emit()


func _load_local_notes() -> void:
	if FileAccess.file_exists(LOCAL_NOTES_PATH):
		var fa := FileAccess.open(LOCAL_NOTES_PATH, FileAccess.READ)
		if fa:
			var content := fa.get_as_text()
			fa.close()
			if notes_text:
				notes_text.text = content
			_is_loaded = true
			if status_label:
				status_label.text = "● Notas Locales (v0.4.0)"
				status_label.modulate = Color(0.22, 0.74, 0.97, 1.0) # Cian
			return

	if notes_text:
		notes_text.text = "[b][color=#00f0ff]ASTRA DREAM // NOTAS DEL PARCHE[/color][/b]\nRegistro de versiones disponible en el repositorio de GitHub."


func _fetch_remote_notes() -> void:
	if _is_fetching or not http_request:
		return

	_is_fetching = true
	if status_label:
		status_label.text = "● Consultando GitHub..."
		status_label.modulate = Color(1.0, 0.8, 0.2, 1.0) # Ámbar

	var err := http_request.request(GITHUB_README_URL)
	if err != OK:
		_is_fetching = false
		if status_label:
			status_label.text = "● Modo Local (Sin Conexión)"
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
				status_label.text = "● Conectado a GitHub (Sincronizado con Master)"
				status_label.modulate = Color(0.22, 0.94, 0.49, 1.0) # Verde
			return

	# Fallback a notas locales si hubo error
	if status_label:
		status_label.text = "● Modo Local (Offline)"
		status_label.modulate = Color(0.6, 0.7, 0.8, 0.8)


func _parse_patch_notes_from_readme(markdown: String) -> String:
	# Busca la sección de Notas del Parche en el README
	var start_idx := markdown.find("## 📝 Notas del Parche")
	if start_idx == -1:
		start_idx = markdown.find("Notas del Parche")
	if start_idx == -1:
		return ""

	var end_idx := markdown.find("\n## ", start_idx + 10)
	var section := markdown.substr(start_idx, (end_idx - start_idx) if end_idx != -1 else -1)

	# Transformación ligera de Markdown a BBCode para lectura limpia
	var bbcode := section
	bbcode = bbcode.replace("## 📝 Notas del Parche / Registro de Actualizaciones (v0.4.0 - Master)", "[b][color=#00f0ff]ASTRA DREAM — NOTAS DEL PARCHE (v0.4.0 - Master)[/color][/b]\n[color=#70a1ff]Sincronizado en tiempo real desde GitHub origin/master[/color]\n")
	bbcode = bbcode.replace("### 🚀 Últimas Novedades y Sistemas Implementados", "")
	bbcode = bbcode.replace("#### 🎯 Armamento Balístico Autónomo (Capa Pasiva Rediseñada)", "\n[b][color=#ffeaa7]━━━ 🎯 ARMAMENTO BALÍSTICO AUTÓNOMO (CAPA PASIVA) ━━━[/color][/b]")
	bbcode = bbcode.replace("#### ⚡ Maniobras Evasivas Avanzadas (Dashes Únicos por Heroína)", "\n[b][color=#ffeaa7]━━━ ⚡ MANIOBRAS EVASIVAS AVANZADAS (DASHES ÚNICOS) ━━━[/color][/b]")
	bbcode = bbcode.replace("#### 🌌 Hangar Estelar 3D & Mirador Panorámico", "\n[b][color=#ffeaa7]━━━ 🌌 HANGAR ESTELAR 3D & MIRADOR PANORÁMICO ━━━[/color][/b]")
	bbcode = bbcode.replace("#### 📡 Radar Perimétrico Orbital & HUD Táctico", "\n[b][color=#ffeaa7]━━━ 📡 RADAR PERIMÉTRICO ORBITAL & HUD TÁCTICO ━━━[/color][/b]")

	# Convertir negritas markdown **texto** a [b]texto[/b]
	var regex := RegEx.new()
	regex.compile("\\*\\*(.*?)\\*\\*")
	bbcode = regex.sub(bbcode, "[b]$1[/b]", true)

	return bbcode


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.is_pressed() and event.keycode == KEY_N):
		close_modal()
		get_viewport().set_input_as_handled()
