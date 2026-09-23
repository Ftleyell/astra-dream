extends Range

var enabled: bool = true

func _process(_delta : float) -> void:
	if !enabled:
		hide()
		return
	var dialogic = DialogicUtil.autoload()
	if not is_instance_valid(dialogic) or not is_instance_valid(dialogic.Inputs) or dialogic.Inputs.auto_advance == null:
		hide()
		return
	if dialogic.Inputs.auto_advance.get_progress() < 0:
		hide()
	else:
		show()
		value = dialogic.Inputs.auto_advance.get_progress()
