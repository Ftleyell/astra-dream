class_name CosmicHasher
extends RefCounted

## Hashing matemático determinista y stateless (variante SplitMix64) para 64-bit signed integers en GDScript.
## Garantiza dispersión determinista uniforme en el rango normalizado [0.0, 1.0) sin estados internos ni asignaciones.

const BIT_MIXER_1: int = -7046029254386353131 # 0x9E3779B97F4A7C15
const BIT_MIXER_2: int = -4417276706814111751 # 0xC2B2AE3D27D4EB4F
const BIT_MIXER_3: int = 3266489917342721      # 0x00165667B19E3779

static func hash_2d(x: int, y: int, seed: int) -> int:
	var h: int = seed ^ (x * BIT_MIXER_1)
	h = (h ^ (h >> 30)) * BIT_MIXER_2
	h = h ^ (y * BIT_MIXER_3)
	h = (h ^ (h >> 27)) * BIT_MIXER_1
	h = h ^ (h >> 31)
	return h

static func hash_2d_float(x: int, y: int, seed: int) -> float:
	var raw_hash: int = hash_2d(x, y, seed)
	var positive_bits: int = raw_hash & 0x7FFFFFFFFFFFFFFF
	return float(positive_bits) / 9223372036854775807.0

static func hash_2d_vector(x: int, y: int, seed: int) -> Vector2:
	var vx: float = hash_2d_float(x, y, seed)
	var vy: float = hash_2d_float(x, y, seed + 1013904223)
	return Vector2(vx, vy)
