class_name CosmicHasher
extends RefCounted

## CosmicHasher
## Generador determinista de hash y números pseudo-aleatorios sin estado en O(1).
## Basado en el algoritmo SquirrelNoise5 (Squirrel Eiserloh, GDC).
## Garantiza reproducibilidad absoluta en coordenadas 2D y semillas enteras sin overhead de memoria.

const NOISE_BIT_NOISE1: int = 0xD2A80A3F
const NOISE_BIT_NOISE2: int = 0xA884F197
const NOISE_BIT_NOISE3: int = 0x6C736F4B
const NOISE_BIT_NOISE4: int = 0xB79F3ABB
const NOISE_BIT_NOISE5: int = 0x1B56C4F5

const PRIME_X: int = 198491317
const PRIME_Y: int = 6542989


## Retorna un hash entero de 32 bits para un índice n y semilla dada.
static func hash_1d(index: int, seed_val: int = 0) -> int:
	var mangled: int = index
	mangled = (mangled * NOISE_BIT_NOISE1) & 0xFFFFFFFF
	mangled = (mangled + seed_val) & 0xFFFFFFFF
	mangled = (mangled ^ (mangled >> 9)) & 0xFFFFFFFF
	mangled = (mangled + NOISE_BIT_NOISE2) & 0xFFFFFFFF
	mangled = (mangled ^ (mangled >> 11)) & 0xFFFFFFFF
	mangled = (mangled * NOISE_BIT_NOISE3) & 0xFFFFFFFF
	mangled = (mangled ^ (mangled >> 13)) & 0xFFFFFFFF
	mangled = (mangled + NOISE_BIT_NOISE4) & 0xFFFFFFFF
	mangled = (mangled ^ (mangled >> 15)) & 0xFFFFFFFF
	mangled = (mangled * NOISE_BIT_NOISE5) & 0xFFFFFFFF
	mangled = (mangled ^ (mangled >> 17)) & 0xFFFFFFFF
	return mangled


## Retorna un hash entero de 32 bits disperso para coordenadas 2D (x, y) y semilla dada.
static func hash_2d(pos_x: int, pos_y: int, seed_val: int = 0) -> int:
	var flat_index: int = ((pos_x * PRIME_X) + (pos_y * PRIME_Y)) & 0xFFFFFFFF
	return hash_1d(flat_index, seed_val)


## Retorna un flotante determinista normalizado en el rango [0.0, 1.0) a partir de un entero.
static func hash_1d_float(index: int, seed_val: int = 0) -> float:
	var h: int = hash_1d(index, seed_val)
	return float(h) / 4294967296.0


## Retorna un flotante determinista normalizado en el rango [0.0, 1.0) a partir de coordenadas 2D.
static func hash_2d_float(pos_x: int, pos_y: int, seed_val: int = 0) -> float:
	var h: int = hash_2d(pos_x, pos_y, seed_val)
	return float(h) / 4294967296.0


## Retorna un flotante determinista en el rango [min_val, max_val].
static func hash_2d_range(pos_x: int, pos_y: int, min_val: float, max_val: float, seed_val: int = 0) -> float:
	return min_val + (max_val - min_val) * hash_2d_float(pos_x, pos_y, seed_val)


## Genera un vector 2D pseudoaleatorio unitario uniforme en base a coordenadas de celda y semilla.
static func hash_2d_direction(pos_x: int, pos_y: int, seed_val: int = 0) -> Vector2:
	var angle: float = hash_2d_float(pos_x, pos_y, seed_val) * TAU
	return Vector2(cos(angle), sin(angle))
