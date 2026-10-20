class_name PlanetMath
extends RefCounted

## Pure static mathematical contracts for Cube-Sphere Quadtree planet.
## Follows .antigravity/rules.md: Cube-Sphere projection with tangential warp
## tan(uv * PI / 4.0) to eliminate corner grid stretching.

const QUARTER_PI: float = 0.7853981633974483

# 6 Cube Face unit normals: +X, -X, +Y, -Y, +Z, -Z
const FACE_NORMALS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0),   # 0: +X (Right)
	Vector3(-1.0, 0.0, 0.0),  # 1: -X (Left)
	Vector3(0.0, 1.0, 0.0),   # 2: +Y (Top)
	Vector3(0.0, -1.0, 0.0),  # 3: -Y (Bottom)
	Vector3(0.0, 0.0, 1.0),   # 4: +Z (Front)
	Vector3(0.0, 0.0, -1.0)   # 5: -Z (Back)
]

# Precomputed tangent vectors matching planet_chunk.glsl
const FACE_TANGENTS: Array[Vector3] = [
	Vector3(0.0, 0.0, -1.0),  # 0: +X
	Vector3(0.0, 0.0, 1.0),   # 1: -X
	Vector3(0.0, 0.0, 1.0),   # 2: +Y
	Vector3(0.0, 0.0, -1.0),  # 3: -Y
	Vector3(1.0, 0.0, 0.0),   # 4: +Z
	Vector3(-1.0, 0.0, 0.0)   # 5: -Z
]

# Precomputed bitangent vectors matching planet_chunk.glsl
const FACE_BITANGENTS: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0),   # 0: +X
	Vector3(0.0, 1.0, 0.0),   # 1: -X
	Vector3(1.0, 0.0, 0.0),   # 2: +Y
	Vector3(1.0, 0.0, 0.0),   # 3: -Y
	Vector3(0.0, 1.0, 0.0),   # 4: +Z
	Vector3(0.0, 1.0, 0.0)    # 5: -Z
]

## Reconstructs face basis [n, t, b] matching planet_chunk.glsl (retained for backward compatibility)
static func get_face_basis(face_index: int) -> Array[Vector3]:
	return [FACE_NORMALS[face_index], FACE_TANGENTS[face_index], FACE_BITANGENTS[face_index]]

## Cube face coordinate [-1, 1] mapped to unit sphere direction via tan warp (zero-allocation)
static func face_uv_to_sphere_dir(face_index: int, uv: Vector2) -> Vector3:
	var n: Vector3 = FACE_NORMALS[face_index]
	var t: Vector3 = FACE_TANGENTS[face_index]
	var b: Vector3 = FACE_BITANGENTS[face_index]
	var wx: float = tan(uv.x * QUARTER_PI)
	var wy: float = tan(uv.y * QUARTER_PI)
	return (n + t * wx + b * wy).normalized()

## Calculates chunk center position on sphere of given radius (zero-allocation primitive)
static func get_chunk_center(face_index: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float) -> Vector3:
	var uv_mid: Vector2 = (uv_min + uv_max) * 0.5
	var center_dir: Vector3 = face_uv_to_sphere_dir(face_index, uv_mid)
	return center_dir * planet_radius

## Calculates chunk bounding radius from center to four warped corners (zero-allocation primitive)
static func get_chunk_radius(face_index: int, uv_min: Vector2, uv_max: Vector2, center_pos: Vector3, planet_radius: float) -> float:
	var c1: Vector3 = face_uv_to_sphere_dir(face_index, uv_min) * planet_radius
	var c2: Vector3 = face_uv_to_sphere_dir(face_index, Vector2(uv_max.x, uv_min.y)) * planet_radius
	var c3: Vector3 = face_uv_to_sphere_dir(face_index, uv_max) * planet_radius
	var c4: Vector3 = face_uv_to_sphere_dir(face_index, Vector2(uv_min.x, uv_max.y)) * planet_radius
	var r1: float = center_pos.distance_to(c1)
	var r2: float = center_pos.distance_to(c2)
	var r3: float = center_pos.distance_to(c3)
	var r4: float = center_pos.distance_to(c4)
	return maxf(maxf(r1, r2), maxf(r3, r4))

## Calculates bounding center and sphere radius for a chunk (retained for backward compatibility)
static func get_chunk_bounds(face_index: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float) -> Dictionary:
	var c: Vector3 = get_chunk_center(face_index, uv_min, uv_max, planet_radius)
	var r: float = get_chunk_radius(face_index, uv_min, uv_max, c, planet_radius)
	return {
		"center": c,
		"radius": r
	}
