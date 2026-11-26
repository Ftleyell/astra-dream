class_name SfxWaveformPreview
extends Control
## Widget de forma de onda con alerta visual de silencio inicial y playhead en tiempo real.

var _peaks: PackedFloat32Array = PackedFloat32Array()
var _duration_ms: float = 0.0
var _sample_rate: int = 44100
var _stereo: bool = false
var _leading_silence_ms: float = -1.0
var _playhead_ratio: float = -1.0
var _status_message: String = "Seleccioná un archivo de audio para inspeccionar su forma de onda."


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 96.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_analysis(data: Dictionary, fallback_label: String = "") -> void:
	_peaks = data.get("peaks", PackedFloat32Array()) as PackedFloat32Array
	_duration_ms = float(data.get("duration_ms", 0.0))
	_sample_rate = int(data.get("sample_rate", 44100))
	_stereo = bool(data.get("stereo", false))
	_leading_silence_ms = float(data.get("leading_silence_ms", -1.0))
	_playhead_ratio = -1.0
	if not str(data.get("error", "")).is_empty():
		_status_message = str(data.get("error", ""))
	elif _peaks.is_empty() and _duration_ms > 0.0:
		_status_message = "Formato comprimido (preview disponible · se normaliza a WAV al exportar)"
	elif not fallback_label.is_empty() and _duration_ms <= 0.0:
		_status_message = fallback_label
	else:
		_status_message = ""
	queue_redraw()


func clear_preview(message: String = "Sin audio seleccionado.") -> void:
	_peaks = PackedFloat32Array()
	_duration_ms = 0.0
	_leading_silence_ms = -1.0
	_playhead_ratio = -1.0
	_status_message = message
	queue_redraw()


func set_playhead_ratio(ratio: float) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0) if ratio >= 0.0 else -1.0
	if is_equal_approx(_playhead_ratio, clamped):
		return
	_playhead_ratio = clamped
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.03, 0.05, 0.09, 0.96), true)
	draw_rect(rect, Color(0.20, 0.78, 0.96, 0.45), false, 1.5)

	var mid_y: float = size.y * 0.5
	draw_line(Vector2(6.0, mid_y), Vector2(size.x - 6.0, mid_y), Color(0.22, 0.34, 0.48, 0.55), 1.0)

	var pad_x: float = 8.0
	var pad_top: float = 22.0
	var pad_bottom: float = 8.0
	var draw_w: float = maxf(1.0, size.x - pad_x * 2.0)
	var draw_h: float = maxf(8.0, size.y - pad_top - pad_bottom)
	var wave_mid_y: float = pad_top + draw_h * 0.5

	if _leading_silence_ms > 10.0 and _duration_ms > 0.0:
		var sil_ratio: float = clampf(_leading_silence_ms / _duration_ms, 0.0, 0.85)
		var sil_w: float = maxf(4.0, draw_w * sil_ratio)
		draw_rect(Rect2(pad_x, pad_top, sil_w, draw_h), Color(0.95, 0.25, 0.35, 0.22), true)
		draw_line(
			Vector2(pad_x + sil_w, pad_top),
			Vector2(pad_x + sil_w, pad_top + draw_h),
			Color(1.0, 0.35, 0.42, 0.8),
			1.0
		)

	if not _peaks.is_empty():
		var count: int = _peaks.size()
		var step_w: float = draw_w / float(count)
		var bar_w: float = maxf(1.5, step_w - 1.0)
		for i: int in range(count):
			var amp: float = clampf(_peaks[i], 0.02, 1.0)
			var half_h: float = amp * (draw_h * 0.48)
			var bx: float = pad_x + float(i) * step_w
			var col := Color(0.28, 0.92, 1.0, 0.90)
			if amp > 0.92:
				col = Color(1.0, 0.68, 0.28, 0.95)
			draw_rect(Rect2(bx, wave_mid_y - half_h, bar_w, maxf(2.0, half_h * 2.0)), col, true)
	elif not _status_message.is_empty():
		var font: Font = ThemeDB.fallback_font
		if font != null:
			draw_string(
				font,
				Vector2(pad_x + 4.0, wave_mid_y + 4.0),
				_status_message,
				HORIZONTAL_ALIGNMENT_LEFT,
				draw_w - 8.0,
				11,
				Color(0.75, 0.84, 0.94, 0.85)
			)

	if _playhead_ratio >= 0.0:
		var px: float = pad_x + draw_w * _playhead_ratio
		draw_line(Vector2(px, pad_top - 2.0), Vector2(px, size.y - 4.0), Color(1.0, 0.92, 0.38, 0.95), 2.0)

	var header_font: Font = ThemeDB.fallback_font
	if header_font != null and _duration_ms > 0.0:
		var ch_str: String = "Stereo" if _stereo else "Mono"
		var sil_str: String = "N/A"
		if _leading_silence_ms >= 0.0:
			sil_str = "%.0f ms%s" % [_leading_silence_ms, " !" if _leading_silence_ms > 10.0 else ""]
		var badge: String = "%.0f ms  |  %d Hz  |  %s  |  Silencio: %s" % [
			_duration_ms,
			_sample_rate,
			ch_str,
			sil_str,
		]
		var badge_col := Color(0.76, 0.90, 1.0, 0.95)
		if _leading_silence_ms > 10.0:
			badge_col = Color(1.0, 0.56, 0.52, 0.98)
		draw_string(header_font, Vector2(pad_x, 15.0), badge, HORIZONTAL_ALIGNMENT_LEFT, draw_w, 11, badge_col)
