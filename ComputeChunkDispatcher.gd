extends RefCounted

## Vulkan compute bridge for planet_chunk.glsl with deterministic CPU fallback.
## std430 PlanetVertex layout: vec4 position_uvx + vec4 normal_uvy = 32 bytes.

const WORKGROUP_X: int = 5
const WORKGROUP_Y: int = 5
const WORKGROUP_Z: int = 1
const LOCAL_SIZE_X: int = 8
const LOCAL_SIZE_Y: int = 8
const LOCAL_SIZE_Z: int = 1
const VERTEX_STRIDE_BYTES: int = 32
const VERTEX_COUNT: int = 1156
const STORAGE_BUFFER_SIZE_BYTES: int = 36992
const SHADER_PATH: String = "res://planet_chunk.glsl"
const FLOATS_PER_VERTEX: int = 8

var rendering_device: RenderingDevice = null
var shader_rid: RID = RID()
var pipeline_rid: RID = RID()
var storage_buffer_rid: RID = RID()
var uniform_set_rid: RID = RID()
var is_headless: bool = false
var use_gpu: bool = false
var fallback_reason: String = ""
var last_vertex_buffer: PackedByteArray = PackedByteArray()
var last_vertices: PackedVector4Array = PackedVector4Array()
var last_normals: PackedVector4Array = PackedVector4Array()

func _init(force_headless: bool = false) -> void:
	last_vertex_buffer.resize(STORAGE_BUFFER_SIZE_BYTES)
	last_vertices.resize(VERTEX_COUNT)
	last_normals.resize(VERTEX_COUNT)
	is_headless = force_headless or DisplayServer.get_name() == "headless"
	_initialize_compute()

func _initialize_compute() -> void:
	if is_headless:
		fallback_reason = "headless dummy renderer"
		return
	rendering_device = RenderingServer.create_local_rendering_device()
	if rendering_device == null:
		fallback_reason = "local RenderingDevice unavailable"
		return
	var shader_file: RDShaderFile = load(SHADER_PATH)
	if shader_file == null:
		fallback_reason = "planet_chunk.glsl load failed"
		return
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	if spirv == null or not spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE).is_empty():
		fallback_reason = "planet_chunk.glsl compute compile failed"
		return
	shader_rid = rendering_device.shader_create_from_spirv(spirv, "PlanetChunk")
	if not shader_rid.is_valid():
		fallback_reason = "compute shader creation failed"
		return
	pipeline_rid = rendering_device.compute_pipeline_create(shader_rid)
	if not pipeline_rid.is_valid():
		fallback_reason = "compute pipeline creation failed"
		return
	storage_buffer_rid = rendering_device.storage_buffer_create(
		STORAGE_BUFFER_SIZE_BYTES, PackedByteArray()
	)
	if not storage_buffer_rid.is_valid():
		fallback_reason = "std430 storage buffer creation failed"
		return
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	uniform.add_id(storage_buffer_rid)
	uniform_set_rid = rendering_device.uniform_set_create([uniform], shader_rid, 0)
	use_gpu = uniform_set_rid.is_valid()
	if not use_gpu:
		fallback_reason = "compute uniform set creation failed"

## Generates the chunk through Vulkan when available, otherwise the exact CPU path.
func dispatch_chunk(
	face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float,
	target_mesh: ArrayMesh = null, slot_idx: int = 0
) -> ArrayMesh:
	if use_gpu and _dispatch_gpu(face_index, lod_level, uv_min, uv_max, planet_radius, seed_val, freq, amp):
		var mesh: ArrayMesh = target_mesh if target_mesh != null else ArrayMesh.new()
		_upload_vertex_buffer_to_mesh(mesh)
		return mesh
	if use_gpu:
		use_gpu = false
		fallback_reason = "compute dispatch/readback failed"
	return TerrainMeshBuilder.build_mesh_cpu(
		face_index, lod_level, uv_min, uv_max, planet_radius, seed_val,
		freq, amp, target_mesh, true, slot_idx
	)

func _dispatch_gpu(
	face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2,
	planet_radius: float, seed_val: int, freq: float, amp: float
) -> bool:
	var push_constants: PackedByteArray = TerrainMeshBuilder.pack_push_constants(
		face_index, lod_level, uv_min, uv_max, planet_radius, seed_val, freq, amp
	)
	rendering_device.buffer_clear(storage_buffer_rid, 0, STORAGE_BUFFER_SIZE_BYTES)
	var compute_list: int = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)
	rendering_device.compute_list_set_push_constant(compute_list, push_constants, 48)
	rendering_device.compute_list_dispatch(compute_list, WORKGROUP_X, WORKGROUP_Y, WORKGROUP_Z)
	rendering_device.compute_list_end()
	rendering_device.submit()
	rendering_device.sync()
	var raw: PackedByteArray = rendering_device.buffer_get_data(
		storage_buffer_rid, 0, STORAGE_BUFFER_SIZE_BYTES
	)
	if raw.size() != STORAGE_BUFFER_SIZE_BYTES:
		return false
	last_vertex_buffer = raw
	unpack_std430_vertex_buffer(raw, 0)
	return true

func _upload_vertex_buffer_to_mesh(target_mesh: ArrayMesh) -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	vertices.resize(VERTEX_COUNT)
	normals.resize(VERTEX_COUNT)
	uvs.resize(VERTEX_COUNT)
	for i in range(VERTEX_COUNT):
		var p: Vector4 = last_vertices[i]
		var n: Vector4 = last_normals[i]
		vertices[i] = Vector3(p.x, p.y, p.z)
		normals[i] = Vector3(n.x, n.y, n.z)
		uvs[i] = Vector2(p.w, n.w)
	target_mesh.clear_surfaces()
	target_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, [
		vertices, normals, uvs, TerrainMeshBuilder._indices
	])

## Reconstructs PlanetVertex[] from the exact std430 byte layout.
func unpack_std430_vertex_buffer(raw_bytes: PackedByteArray, slot_idx: int = 0) -> bool:
	var slot: int = clampi(slot_idx, 0, TerrainMeshBuilder.MAX_WORKERS - 1)
	if raw_bytes.size() != STORAGE_BUFFER_SIZE_BYTES:
		return false
	var offset: int = 0
	for i in range(VERTEX_COUNT):
		var px: float = raw_bytes.decode_float(offset)
		var py: float = raw_bytes.decode_float(offset + 4)
		var pz: float = raw_bytes.decode_float(offset + 8)
		var uvx: float = raw_bytes.decode_float(offset + 12)
		var nx: float = raw_bytes.decode_float(offset + 16)
		var ny: float = raw_bytes.decode_float(offset + 20)
		var nz: float = raw_bytes.decode_float(offset + 24)
		var uvy: float = raw_bytes.decode_float(offset + 28)
		last_vertices[i] = Vector4(px, py, pz, uvx)
		last_normals[i] = Vector4(nx, ny, nz, uvy)
		offset += VERTEX_STRIDE_BYTES
	return true

## Packs the current deterministic CPU vertex arrays into PlanetVertex std430 bytes.
func pack_std430_vertex_buffer(slot_idx: int = 0) -> PackedByteArray:
	var slot: int = clampi(slot_idx, 0, TerrainMeshBuilder.MAX_WORKERS - 1)
	TerrainMeshBuilder.init_builder()
	var verts: PackedVector3Array = TerrainMeshBuilder._vertices_pool[slot]
	var norms: PackedVector3Array = TerrainMeshBuilder._normals_pool[slot]
	var uvs: PackedVector2Array = TerrainMeshBuilder._uvs_pool[slot]
	last_vertex_buffer.resize(STORAGE_BUFFER_SIZE_BYTES)
	var offset: int = 0
	for i in range(VERTEX_COUNT):
		var p: Vector3 = verts[i]
		var n: Vector3 = norms[i]
		var uv: Vector2 = uvs[i]
		last_vertex_buffer.encode_float(offset, p.x)
		last_vertex_buffer.encode_float(offset + 4, p.y)
		last_vertex_buffer.encode_float(offset + 8, p.z)
		last_vertex_buffer.encode_float(offset + 12, uv.x)
		last_vertex_buffer.encode_float(offset + 16, n.x)
		last_vertex_buffer.encode_float(offset + 20, n.y)
		last_vertex_buffer.encode_float(offset + 24, n.z)
		last_vertex_buffer.encode_float(offset + 28, uv.y)
		last_vertices[i] = Vector4(p.x, p.y, p.z, uv.x)
		last_normals[i] = Vector4(n.x, n.y, n.z, uv.y)
		offset += VERTEX_STRIDE_BYTES
	return last_vertex_buffer

func get_dispatch_group_count() -> Vector3i:
	return Vector3i(WORKGROUP_X, WORKGROUP_Y, WORKGROUP_Z)

func get_invocation_count() -> int:
	return WORKGROUP_X * LOCAL_SIZE_X * WORKGROUP_Y * LOCAL_SIZE_Y * WORKGROUP_Z * LOCAL_SIZE_Z

func get_effective_backend() -> String:
	return "vulkan_compute" if use_gpu else "cpu_fallback"

func shutdown() -> void:
	if rendering_device == null:
		return
	if uniform_set_rid.is_valid():
		rendering_device.free_rid(uniform_set_rid)
	if storage_buffer_rid.is_valid():
		rendering_device.free_rid(storage_buffer_rid)
	if pipeline_rid.is_valid():
		rendering_device.free_rid(pipeline_rid)
	if shader_rid.is_valid():
		rendering_device.free_rid(shader_rid)
	uniform_set_rid = RID()
	storage_buffer_rid = RID()
	pipeline_rid = RID()
	shader_rid = RID()
	rendering_device = null
	use_gpu = false
