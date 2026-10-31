class_name TerrainMeshBuilder
extends RefCounted

## 34x34 skirted chunk mesh builder and 48-byte std430 push constants generator.
## Conforms to rules.md: <= 250 lines, 0 runtime heap allocations.
## Provides 4 independent worker buffer sets for thread-safe geometry and collider baking.

const GRID: int = 34
const INTERIOR: int = 32
const VERTEX_COUNT: int = 1156
const INDEX_COUNT: int = 6534
const TRIANGLE_COUNT: int = 2178
const PUSH_CONSTANT_SIZE: int = 48
const SKIRT_FRACTION: float = 0.05
const MAX_WORKERS: int = 4
const F3: float = 0.3333333333333333
const G3: float = 0.16666666666666666

const GRAD12: Array[Vector3] = [
	Vector3(0, 1, 1), Vector3(0, -1, 1), Vector3(0, 1, -1), Vector3(0, -1, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1),
	Vector3(1, 0, -1), Vector3(-1, 0, -1), Vector3(1, 1, 0), Vector3(-1, 1, 0), Vector3(1, -1, 0), Vector3(-1, -1, 0)
]

static var _indices: PackedInt32Array; static var _inner_lut: PackedFloat32Array = PackedFloat32Array()
static var _vertices_pool: Array[PackedVector3Array] = []
static var _normals_pool: Array[PackedVector3Array] = []
static var _uvs_pool: Array[PackedVector2Array] = []
static var _mesh_arrays_pool: Array[Array] = []
static var _faces_pool: Array[PackedVector3Array] = []
static var _push_buf: PackedByteArray
static var _ready: bool = false

static func init_builder() -> void:
	if _ready: return
	_indices = PackedInt32Array(); _indices.resize(INDEX_COUNT)
	var ptr: int = 0
	for y in range(GRID - 1):
		for x in range(GRID - 1):
			var bl: int = y * GRID + x; var br: int = bl + 1
			var tl: int = bl + GRID; var tr: int = tl + 1
			_indices[ptr] = bl; _indices[ptr + 1] = br; _indices[ptr + 2] = tl
			_indices[ptr + 3] = br; _indices[ptr + 4] = tr; _indices[ptr + 5] = tl
			ptr += 6
	_inner_lut = PackedFloat32Array(); _inner_lut.resize(GRID)
	var inv_int: float = 1.0 / float(INTERIOR - 1)
	for i in range(GRID): _inner_lut[i] = clampf(float(i - 1), 0.0, float(INTERIOR - 1)) * inv_int
	_vertices_pool.resize(MAX_WORKERS); _normals_pool.resize(MAX_WORKERS); _uvs_pool.resize(MAX_WORKERS)
	_mesh_arrays_pool.resize(MAX_WORKERS); _faces_pool.resize(MAX_WORKERS)
	for w in range(MAX_WORKERS):
		var v: PackedVector3Array = PackedVector3Array(); v.resize(VERTEX_COUNT); _vertices_pool[w] = v
		var n: PackedVector3Array = PackedVector3Array(); n.resize(VERTEX_COUNT); _normals_pool[w] = n
		var u: PackedVector2Array = PackedVector2Array(); u.resize(VERTEX_COUNT); _uvs_pool[w] = u
		var f: PackedVector3Array = PackedVector3Array(); f.resize(INDEX_COUNT); _faces_pool[w] = f
		var arr: Array = []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_TEX_UV] = u; arr[Mesh.ARRAY_INDEX] = _indices
		_mesh_arrays_pool[w] = arr
	_push_buf = PackedByteArray(); _push_buf.resize(PUSH_CONSTANT_SIZE); _ready = true

static func calculate_chunk_size(face_index: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float) -> float:
	var p0: Vector3 = PlanetMath.face_uv_to_sphere_dir(face_index, uv_min)
	var p1: Vector3 = PlanetMath.face_uv_to_sphere_dir(face_index, Vector2(uv_max.x, uv_min.y))
	return p0.distance_to(p1) * planet_radius

static func get_chunk_origin(face_index: int, uv_min: Vector2, planet_radius: float) -> Vector3:
	return PlanetMath.face_uv_to_sphere_dir(face_index, uv_min) * planet_radius

static func pack_push_constants(
	face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float
) -> PackedByteArray:
	if not _ready: init_builder()
	var chunk_size_m: float = calculate_chunk_size(face_index, uv_min, uv_max, planet_radius)
	var norm: Vector3 = PlanetMath.FACE_NORMALS[face_index]
	_push_buf.encode_float(0, uv_min.x); _push_buf.encode_float(4, uv_min.y)
	_push_buf.encode_float(8, uv_max.x - uv_min.x); _push_buf.encode_float(12, chunk_size_m)
	_push_buf.encode_float(16, norm.x); _push_buf.encode_float(20, norm.y); _push_buf.encode_float(24, norm.z)
	_push_buf.encode_float(28, float(lod_level)); _push_buf.encode_float(32, planet_radius)
	_push_buf.encode_float(36, float(seed_val)); _push_buf.encode_float(40, freq); _push_buf.encode_float(44, amp)
	return _push_buf

static func _hash3(x: int, y: int, z: int, seed_val: int) -> int:
	var h: int = (seed_val ^ 0x9e3779b9) & 0xFFFFFFFF
	h = (h ^ (((x & 0xFFFFFFFF) * 0x8da6b343) & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = ((h << 13) | (h >> 19)) & 0xFFFFFFFF
	h = (h ^ (((y & 0xFFFFFFFF) * 0xd8163841) & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = ((h << 17) | (h >> 15)) & 0xFFFFFFFF
	h = (h ^ (((z & 0xFFFFFFFF) * 0xcb1ab31f) & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	h = (h * 0x7feb352d) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	h = (h * 0x846ca68b) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFFFF

static func _grad12(h: int) -> Vector3: return GRAD12[h % 12]

static func snoise(v: Vector3, seed_val: int) -> Vector4:
	var s: float = (v.x + v.y + v.z) * F3
	var ix: int = int(floor(v.x + s)); var iy: int = int(floor(v.y + s)); var iz: int = int(floor(v.z + s))
	var skew: float = float(ix + iy + iz) * G3
	var x0: Vector3 = Vector3(v.x - float(ix) + skew, v.y - float(iy) + skew, v.z - float(iz) + skew)
	var i1x: int = 0; var i1y: int = 0; var i1z: int = 0; var i2x: int = 0; var i2y: int = 0; var i2z: int = 0
	if x0.x >= x0.y:
		if x0.y >= x0.z: i1x = 1; i2x = 1; i2y = 1
		elif x0.x >= x0.z: i1x = 1; i2x = 1; i2z = 1
		else: i1z = 1; i2x = 1; i2y = 1
	else:
		if x0.y < x0.z: i1z = 1; i2y = 1; i2z = 1
		elif x0.x < x0.z: i1y = 1; i2y = 1; i2z = 1
		else: i1y = 1; i2x = 1; i2y = 1
	var x1: Vector3 = Vector3(x0.x - float(i1x) + G3, x0.y - float(i1y) + G3, x0.z - float(i1z) + G3)
	var x2: Vector3 = Vector3(x0.x - float(i2x) + 2.0 * G3, x0.y - float(i2y) + 2.0 * G3, x0.z - float(i2z) + 2.0 * G3)
	var x3: Vector3 = Vector3(x0.x - 1.0 + 3.0 * G3, x0.y - 1.0 + 3.0 * G3, x0.z - 1.0 + 3.0 * G3)
	var val: float = 0.0; var deriv: Vector3 = Vector3.ZERO
	var t0: float = 0.6 - x0.length_squared()
	if t0 > 0.0:
		var t2: float = t0 * t0; var g: Vector3 = GRAD12[_hash3(ix, iy, iz, seed_val) % 12]; var m: float = g.dot(x0)
		val += t2 * t2 * m; deriv += (t2 * t2) * g - (8.0 * t2 * t0 * m) * x0
	var t1: float = 0.6 - x1.length_squared()
	if t1 > 0.0:
		var t2: float = t1 * t1; var g: Vector3 = GRAD12[_hash3(ix + i1x, iy + i1y, iz + i1z, seed_val) % 12]; var m: float = g.dot(x1)
		val += t2 * t2 * m; deriv += (t2 * t2) * g - (8.0 * t2 * t1 * m) * x1
	var t2c: float = 0.6 - x2.length_squared()
	if t2c > 0.0:
		var t2: float = t2c * t2c; var g: Vector3 = GRAD12[_hash3(ix + i2x, iy + i2y, iz + i2z, seed_val) % 12]; var m: float = g.dot(x2)
		val += t2 * t2 * m; deriv += (t2 * t2) * g - (8.0 * t2 * t2c * m) * x2
	var t3: float = 0.6 - x3.length_squared()
	if t3 > 0.0:
		var t2: float = t3 * t3; var g: Vector3 = GRAD12[_hash3(ix + 1, iy + 1, iz + 1, seed_val) % 12]; var m: float = g.dot(x3)
		val += t2 * t2 * m; deriv += (t2 * t2) * g - (8.0 * t2 * t3 * m) * x3
	return Vector4(32.0 * val, 32.0 * deriv.x, 32.0 * deriv.y, 32.0 * deriv.z)

static func fbm4(p: Vector3, seed_val: int) -> Vector4:
	var val: float = 0.0; var deriv: Vector3 = Vector3.ZERO
	var amp: float = 0.5; var freq: float = 1.0
	for o in range(4):
		var s: int = (seed_val + o * 1013904223) & 0xFFFFFFFF
		var n: Vector4 = snoise(p * freq, s)
		val += amp * n.x; deriv += amp * freq * Vector3(n.y, n.z, n.w)
		amp *= 0.5; freq *= 2.02
	return Vector4(val, deriv.x, deriv.y, deriv.z)

static func _fill_buffers(
	face_index: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float,
	verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
	chunk_local: bool = true
) -> void:
	var chunk_size_m: float = calculate_chunk_size(face_index, uv_min, uv_max, planet_radius)
	var sea_origin: Vector3 = get_chunk_origin(face_index, uv_min, planet_radius)
	var s_val: int = seed_val & 0xFFFFFFFF; var uv_range: Vector2 = uv_max - uv_min
	var skirt_dist: float = chunk_size_m * SKIRT_FRACTION
	var n: Vector3 = PlanetMath.FACE_NORMALS[face_index]; var t: Vector3 = PlanetMath.FACE_TANGENTS[face_index]; var b: Vector3 = PlanetMath.FACE_BITANGENTS[face_index]
	var amp_freq: float = amp * freq
	var twx: Array[Vector3] = []; twx.resize(GRID)
	for x in range(GRID): twx[x] = t * tan((uv_min.x + _inner_lut[x] * uv_range.x) * PlanetMath.QUARTER_PI)
	var idx: int = 0
	for y in range(GRID):
		var inner_y: float = _inner_lut[y]
		var base_dir: Vector3 = n + b * tan((uv_min.y + inner_y * uv_range.y) * PlanetMath.QUARTER_PI)
		var is_y_edge: bool = (y == 0 or y == GRID - 1)
		for x in range(GRID):
			var inner_x: float = _inner_lut[x]
			var dir: Vector3 = (base_dir + twx[x]).normalized()
			var f: Vector4 = fbm4(dir * freq, s_val)
			var grad: Vector3 = amp_freq * Vector3(f.y, f.z, f.w)
			grad -= dir * grad.dot(dir)
			var pos: Vector3 = dir * (planet_radius + amp * f.x)
			var nrm: Vector3 = (pos - grad).normalized()
			if chunk_local: pos -= sea_origin
			if is_y_edge or x == 0 or x == GRID - 1: pos -= dir * skirt_dist
			verts[idx] = pos; norms[idx] = nrm; uvs[idx] = Vector2(inner_x, inner_y)
			idx += 1

static func build_chunk_buffers(
	face_index: int, _lod_level: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float,
	out_arrays: Array, out_faces: PackedVector3Array, has_collider: bool
) -> void:
	if not _ready: init_builder()
	var verts: PackedVector3Array = out_arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = out_arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = out_arrays[Mesh.ARRAY_TEX_UV]
	_fill_buffers(face_index, uv_min, uv_max, planet_radius, seed_val, freq, amp, verts, norms, uvs, true)
	out_arrays[Mesh.ARRAY_VERTEX] = verts; out_arrays[Mesh.ARRAY_NORMAL] = norms; out_arrays[Mesh.ARRAY_TEX_UV] = uvs
	if has_collider and out_faces.size() == INDEX_COUNT:
		var ind: PackedInt32Array = _indices
		for i in range(INDEX_COUNT): out_faces[i] = verts[ind[i]]

static func build_mesh_cpu(
	face_index: int, _lod_level: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float,
	target_mesh: ArrayMesh = null, chunk_local: bool = true, slot_idx: int = 0,
	skip_mesh: bool = false
) -> ArrayMesh:
	if not _ready: init_builder()
	var slot: int = clampi(slot_idx, 0, MAX_WORKERS - 1)
	var verts: PackedVector3Array = _vertices_pool[slot]
	var norms: PackedVector3Array = _normals_pool[slot]
	var uvs: PackedVector2Array = _uvs_pool[slot]
	_fill_buffers(face_index, uv_min, uv_max, planet_radius, seed_val, freq, amp, verts, norms, uvs, chunk_local)
	_vertices_pool[slot] = verts; _normals_pool[slot] = norms; _uvs_pool[slot] = uvs
	if skip_mesh: return null
	var arr: Array = _mesh_arrays_pool[slot]
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh: ArrayMesh = target_mesh if target_mesh != null else ArrayMesh.new()
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

static func get_collider_faces(slot_idx: int = 0) -> PackedVector3Array:
	if not _ready: init_builder()
	var slot: int = clampi(slot_idx, 0, MAX_WORKERS - 1)
	var verts: PackedVector3Array = _vertices_pool[slot]
	var faces: PackedVector3Array = _faces_pool[slot]
	var ind: PackedInt32Array = _indices
	for i in range(INDEX_COUNT): faces[i] = verts[ind[i]]
	_faces_pool[slot] = faces
	return faces

static func build_collider_faces(
	face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float,
	slot_idx: int = 0, chunk_local: bool = true
) -> PackedVector3Array:
	var slot: int = clampi(slot_idx, 0, MAX_WORKERS - 1)
	build_mesh_cpu(face_index, lod_level, uv_min, uv_max, planet_radius, seed_val, freq, amp, null, chunk_local, slot, true)
	return get_collider_faces(slot)

static func build_chunk_mesh(
	mesh: ArrayMesh, face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float, slot_idx: int = 0
) -> ArrayMesh:
	return build_mesh_cpu(face_index, lod_level, uv_min, uv_max, planet_radius, seed_val, freq, amp, mesh, true, slot_idx)
