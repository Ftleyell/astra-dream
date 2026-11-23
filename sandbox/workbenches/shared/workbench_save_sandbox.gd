class_name WorkbenchSaveSandbox
extends RefCounted
## Respaldo y restauración determinista del perfil SaveManager en Workbenches/CombatGym.
## Garantiza que probar skins, desbloqueos o economía en sandbox nunca ensucie el perfil real.

var _had_file: bool = false
var _raw_content: String = ""
var _active: bool = false


func backup() -> void:
	if _active:
		return
	_active = true
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		_had_file = true
		_raw_content = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	else:
		_had_file = false
		_raw_content = ""


func reset_to_backup() -> void:
	if not _active:
		return
	Engine.time_scale = 1.0
	if _had_file:
		var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_raw_content)
			f.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func restore() -> void:
	if not _active:
		return
	reset_to_backup()
	_active = false
