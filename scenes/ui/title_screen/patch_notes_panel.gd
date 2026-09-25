class_name PatchNotesPanel
extends PanelContainer

## PatchNotesPanel.gd
## Panel integrado siempre visible en la pantalla de inicio con las notas de la versión.
## Soporta carga instantánea local y actualización asíncrona desde GitHub origin/master (CHANGELOG.md).

@onready var status_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/StatusLabel
@onready var notes_text: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/NotesText
@onready var http_request: HTTPRequest = $HTTPRequest

const GITHUB_CHANGELOG_URL := "https://raw.githubusercontent.com/Ftleyell/astra-dream/master/CHANGELOG.md"
const LOCAL_NOTES_PATH := "res://data/patch_notes_local.txt"
const LOCAL_CHANGELOG_PATH := "res://CHANGELOG.md"

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

	if FileAccess.file_exists(LOCAL_CHANGELOG_PATH):
		var fa := FileAccess.open(LOCAL_CHANGELOG_PATH, FileAccess.READ)
		if fa:
			var content := fa.get_as_text()
			fa.close()
			var parsed := _parse_changelog_to_bbcode(content)
			if notes_text:
				notes_text.text = parsed
			if status_label:
				status_label.text = "● Changelog Local"
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

	var err := http_request.request(GITHUB_CHANGELOG_URL)
	if err != OK:
		_is_fetching = false
		if status_label:
			status_label.text = "● Modo Local"
			status_label.modulate = Color(0.7, 0.7, 0.7, 0.8)


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_fetching = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var raw_md := body.get_string_from_utf8()
		var parsed_bbcode := _parse_changelog_to_bbcode(raw_md)
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


func _parse_changelog_to_bbcode(markdown: String) -> String:
	if markdown.is_empty():
		return ""

	var lines := markdown.split("\n")
	var output: Array[String] = []

	var reg_bold := RegEx.new()
	reg_bold.compile("\\*\\*(.*?)\\*\\*")

	var reg_code := RegEx.new()
	reg_code.compile("`(.*?)`")

	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.begins_with("# Changelog") or trimmed.begins_with("# Astra Dream"):
			output.append("[b][font_size=18][color=#00f0ff]ASTRA DREAM // REGISTRO DE ACTUALIZACIONES[/color][/font_size][/b]")
			output.append("[color=#70a1ff]Sincronizado en tiempo real desde GitHub origin/master[/color]\n")
			continue

		if trimmed.begins_with("Todos los cambios") or trimmed.begins_with("El formato está basado") or trimmed == "---":
			continue

		if trimmed.begins_with("## ["):
			var title := trimmed.trim_prefix("## ")
			output.append("\n[b][color=#00f0ff]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color][/b]")
			output.append("[b][color=#ffeaa7]🚀 " + title + "[/color][/b]")
			output.append("[b][color=#00f0ff]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color][/b]")
			continue

		if trimmed.begins_with("### "):
			var category := trimmed.trim_prefix("### ")
			var cat_color := "#38ef7d" if category == "Añadido" else ("#ffeaa7" if category == "Corregido" else "#74b9ff")
			output.append("\n[b][color=" + cat_color + "]◆ " + category.to_upper() + ":[/color][/b]")
			continue

		var l := line
		if l.begins_with("* **") or l.begins_with("- **"):
			l = "  • " + l.substr(2)
		elif l.begins_with("  * ") or l.begins_with("  - "):
			l = "    └ " + l.substr(4)
		elif l.begins_with("* ") or l.begins_with("- "):
			l = "  • " + l.substr(2)

		l = reg_bold.sub(l, "[b]$1[/b]", true)
		l = reg_code.sub(l, "[color=#00f0ff]$1[/color]", true)

		output.append(l)

	return "\n".join(output)
