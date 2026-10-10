class_name GameOverTelemetryFormatter
extends RefCounted

## Formateador estático puro para cadenas de telemetría y métricas numéricas
## en la pantalla de Game Over / Fin de incursión.

static func format_number_with_separators(n: int) -> String:
	var s: String = str(n)
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

static func format_score_text(score: int) -> String:
	return "%s PTS" % format_number_with_separators(score)

static func format_wave_text(waves_survived: int) -> String:
	return "Oleada %d" % waves_survived

static func format_bosses_text(bosses_defeated: int) -> String:
	return "%d Derrotados" % bosses_defeated

static func format_kills_text(enemies_killed: int) -> String:
	return "%d Bajas" % enemies_killed

static func format_biomass_text(amount: int) -> String:
	return "+%d ☣" % amount

static func format_dark_matter_text(amount: int) -> String:
	return "+%d ✦" % amount

static func format_credits_text(amount: int) -> String:
	return "+%d ⬡" % amount

static func format_pilot_title(pilot_name: String, epilogue_text: String = "") -> String:
	var pilot_line: String = "PILOTO: %s" % pilot_name.to_upper()
	if not epilogue_text.is_empty():
		pilot_line += " | %s" % epilogue_text
	return pilot_line
