class_name RunLaunchRequest
extends RefCounted

## Value Object determinista para lanzamiento de incursiones desde el Hub 3D.
## Encapsula 1 semilla maestra de 31 bits (1 .. 0x7FFFFFFF), su código biyectivo ASTR-XXXXXX,
## el modo de semilla (AUTO / CUSTOM / DAILY) y sub-semillas aisladas por dominio vía CosmosHasher.

const CosmosHasherScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_hasher.gd")
const HubProgressionConfigScript = preload("res://scenes/ui/hub/resources/hub_progression_config.gd")

enum SeedMode {
	AUTO = 0,
	CUSTOM = 1,
	DAILY = 2,
}

const MAX_SEED: int = 0x7FFFFFFF
const CODE_PREFIX: String = "ASTR-"
const CODE_LEN: int = 6
const BASE36_CHARS: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

const SALT_COSMOS := Vector2i(104729, 31337)
const SALT_DIRECTOR := Vector2i(224737, 7919)
const SALT_LOOT := Vector2i(350377, 65537)

var master_seed: int = 1
var seed_mode: SeedMode = SeedMode.AUTO
var coordinate_code: String = ""
var cosmos_seed: int = 1
var run_director_seed: int = 1
var run_loot_seed: int = 1

static var _pending_request: RunLaunchRequest = null
static var _last_launched_request: RunLaunchRequest = null


static func normalize_seed(raw_seed: int) -> int:
	var masked: int = raw_seed & MAX_SEED
	return maxi(1, masked)


static func encode_coordinate_code(seed_val: int) -> String:
	var v: int = normalize_seed(seed_val)
	var chars: Array[String] = ["0", "0", "0", "0", "0", "0"]
	for idx: int in range(CODE_LEN - 1, -1, -1):
		var rem: int = v % 36
		chars[idx] = BASE36_CHARS.substr(rem, 1)
		v = int(v / 36)
	return CODE_PREFIX + "".join(chars)


static func decode_coordinate_code(raw_text: String) -> int:
	var cleaned: String = raw_text.strip_edges().to_upper()
	if cleaned.is_empty():
		return 0

	if cleaned.is_valid_int():
		var parsed_int: int = int(cleaned)
		if parsed_int <= 0:
			return 0
		return normalize_seed(parsed_int)

	if cleaned.begins_with(CODE_PREFIX):
		cleaned = cleaned.substr(CODE_PREFIX.length()).strip_edges()
	elif cleaned.begins_with("ASTR"):
		cleaned = cleaned.substr(4).strip_edges()
		if cleaned.begins_with("-"):
			cleaned = cleaned.substr(1).strip_edges()

	if cleaned.is_empty() or cleaned.length() > CODE_LEN:
		return 0

	var acc: int = 0
	for i: int in range(cleaned.length()):
		var ch: String = cleaned.substr(i, 1)
		var digit: int = BASE36_CHARS.find(ch)
		if digit < 0:
			return 0
		acc = acc * 36 + digit

	if acc <= 0 or acc > MAX_SEED:
		return 0
	return acc


static func derive_subseed(p_master_seed: int, salt: Vector2i) -> int:
	var norm_master: int = normalize_seed(p_master_seed)
	var hashed: int = CosmosHasherScript.hash_2d(salt.x, salt.y, norm_master)
	return normalize_seed(hashed)


static func create(p_master_seed: int, p_mode: SeedMode = SeedMode.AUTO) -> RunLaunchRequest:
	var req := RunLaunchRequest.new()
	var norm_seed: int = normalize_seed(p_master_seed)
	req.master_seed = norm_seed
	req.seed_mode = p_mode
	req.coordinate_code = encode_coordinate_code(norm_seed)
	req.cosmos_seed = derive_subseed(norm_seed, SALT_COSMOS)
	req.run_director_seed = derive_subseed(norm_seed, SALT_DIRECTOR)
	req.run_loot_seed = derive_subseed(norm_seed, SALT_LOOT)
	return req


static func create_random_auto() -> RunLaunchRequest:
	var rnd_seed: int = normalize_seed(int(randi()))
	return create(rnd_seed, SeedMode.AUTO)


static func create_from_code(raw_text: String, p_mode: SeedMode = SeedMode.CUSTOM) -> RunLaunchRequest:
	var decoded: int = decode_coordinate_code(raw_text)
	if decoded <= 0:
		return null
	return create(decoded, p_mode)


func duplicate_request() -> RunLaunchRequest:
	return RunLaunchRequest.create(master_seed, seed_mode)


func is_custom_seeded() -> bool:
	return seed_mode == SeedMode.CUSTOM


func get_seed_badge_text() -> String:
	return "[SEEDED]" if is_custom_seeded() else ""


static func set_pending(req: RunLaunchRequest) -> void:
	_pending_request = req.duplicate_request() if req != null else null


static func peek_pending() -> RunLaunchRequest:
	return _pending_request


static func consume_pending() -> RunLaunchRequest:
	var out: RunLaunchRequest = _pending_request
	_pending_request = null
	if out != null:
		_last_launched_request = out.duplicate_request()
	return out


static func get_last_launched() -> RunLaunchRequest:
	return _last_launched_request


static func clear_pending() -> void:
	_pending_request = null


static func can_record_highscores(req: RunLaunchRequest, cfg: HubProgressionConfigScript) -> bool:
	if req == null or not req.is_custom_seeded():
		return true
	if cfg == null:
		return false
	return cfg.allow_highscores_on_custom_seed


static func can_unlock_trophies(req: RunLaunchRequest, cfg: HubProgressionConfigScript) -> bool:
	if req == null or not req.is_custom_seeded():
		return true
	if cfg == null:
		return false
	return cfg.allow_trophies_on_custom_seed
