class_name PlanetStreamer
extends Node3D

@export var auto_update: bool = false
@export var camera: Node3D = null
@export var seed_base: int = 1337
@export var seed_face_stride: int = 0
@export var noise_frequency: float = 64.0
@export var noise_amplitude: float = 500.0
@export var synchronous_mode: bool = false

const VISUAL_POOL_SIZE: int = 256
const JOB_CAPACITY: int = 64
const MESH_COLLIDER: int = 0
const MESH_JOB: int = 1
const MESH_GENERATION: int = 2
const JOB_ID: int = 0
const JOB_MESH: int = 1
const JOB_GENERATION: int = 2
const JOB_STAGING: int = 3
static var EMPTY_FACES: PackedVector3Array = PackedVector3Array()

var planet_manager: Node = null
var task_scheduler: Node = null
var visuals: Array[MeshInstance3D] = []
var mesh_owners: Array = []
var mesh_state: PackedInt64Array = PackedInt64Array()
var mesh_loaded: PackedByteArray = PackedByteArray()
var mesh_seen: PackedByteArray = PackedByteArray()
var job_state: PackedInt64Array = PackedInt64Array()
var staging_arrays: Array[Array] = []; var staging_faces: Array[PackedVector3Array] = []
var staging_args: Array[Array] = []; var staging_free: Array[int] = []
var retired_jobs: PackedInt64Array = PackedInt64Array(); var retired_staging: PackedInt32Array = PackedInt32Array(); var retired_count: int = 0
var pending_jobs: int = 0; var queued_job_count: int = 0; var cancelled_job_count: int = 0
var compute_dispatcher: ComputeChunkDispatcher = null; var _chunk_pool: RefCounted = null; var _collider_pool: Node3D = null; var _build_job_callable: Callable

func _init() -> void:
	visuals.resize(VISUAL_POOL_SIZE); mesh_owners.resize(VISUAL_POOL_SIZE); mesh_state.resize(VISUAL_POOL_SIZE * 3)
	job_state.resize(JOB_CAPACITY * 4); mesh_loaded.resize(VISUAL_POOL_SIZE); mesh_seen.resize(VISUAL_POOL_SIZE)
	staging_arrays.resize(JOB_CAPACITY); staging_faces.resize(JOB_CAPACITY); staging_args.resize(JOB_CAPACITY); staging_free.resize(JOB_CAPACITY)
	retired_jobs.resize(JOB_CAPACITY); retired_staging.resize(JOB_CAPACITY)
	for i in range(VISUAL_POOL_SIZE):
		var visual: MeshInstance3D = MeshInstance3D.new(); visual.name = "TerrainVisual_%d" % i; visual.visible = false
		add_child(visual); visuals[i] = visual; mesh_state[i * 3 + MESH_COLLIDER] = -1
	TerrainMeshBuilder.init_builder()
	for i in range(JOB_CAPACITY):
		var args: Array = []; args.resize(12); staging_args[i] = args; staging_free[i] = JOB_CAPACITY - 1 - i
		var v: PackedVector3Array = PackedVector3Array(); v.resize(TerrainMeshBuilder.VERTEX_COUNT)
		var n: PackedVector3Array = PackedVector3Array(); n.resize(TerrainMeshBuilder.VERTEX_COUNT)
		var u: PackedVector2Array = PackedVector2Array(); u.resize(TerrainMeshBuilder.VERTEX_COUNT)
		var arr: Array = []; arr.resize(Mesh.ARRAY_MAX); arr[0] = v; arr[1] = n; arr[4] = u; arr[12] = TerrainMeshBuilder._indices; staging_arrays[i] = arr
		var f: PackedVector3Array = PackedVector3Array(); f.resize(TerrainMeshBuilder.INDEX_COUNT); staging_faces[i] = f
	_build_job_callable = Callable(self, "_build_chunk_job")

func setup(planet: Node, scheduler: Node = null, immediate: bool = false) -> void:
	planet_manager = planet; synchronous_mode = immediate
	TerrainMeshBuilder.init_builder(); _chunk_pool = planet.chunk_pool; _collider_pool = planet.collider_pool
	if compute_dispatcher == null: compute_dispatcher = ComputeChunkDispatcher.new()
	for i in range(VISUAL_POOL_SIZE): visuals[i].mesh = _chunk_pool.get_mesh(i)
	task_scheduler = scheduler if scheduler != null else ChunkTaskScheduler.new()
	if task_scheduler.get_parent() == null: add_child(task_scheduler)
	if not task_scheduler.job_completed.is_connected(_on_job_completed): task_scheduler.job_completed.connect(_on_job_completed)
	_sync_planet_origin()

func _process(_delta: float) -> void:
	if auto_update and is_instance_valid(camera): update_streamer(camera.global_position)

func update_streamer(camera_pos: Vector3) -> void:
	if not is_instance_valid(planet_manager): return
	_sync_planet_origin(); if not synchronous_mode: task_scheduler.poll(); _release_retired_staging()
	planet_manager.update_camera(camera_pos); _scan_leaves()

func _scan_leaves() -> void:
	mesh_seen.fill(0)
	for face_idx in range(6): _visit_leaf(planet_manager.face_roots[face_idx])
	for i in range(VISUAL_POOL_SIZE): if mesh_seen[i] == 0 and mesh_owners[i] != null: _reset_slot(i)

func _visit_leaf(node: RefCounted) -> void:
	if not node.is_leaf:
		for child in node.children: _visit_leaf(child)
		return
	var mesh_id: int = node.mesh_id
	if mesh_id < 0 or mesh_id >= VISUAL_POOL_SIZE: return
	mesh_seen[mesh_id] = 1
	var base: int = mesh_id * 3
	var collider_id: int = node.collider_id
	if mesh_owners[mesh_id] != node:
		_reset_slot(mesh_id); mesh_owners[mesh_id] = node
		mesh_state[base + MESH_GENERATION] += 1; mesh_state[base + MESH_COLLIDER] = collider_id
		_queue_or_build(node, mesh_id, collider_id)
	elif mesh_state[base + MESH_COLLIDER] != collider_id:
		_cancel_slot_job(mesh_id); mesh_state[base + MESH_COLLIDER] = collider_id
		mesh_loaded[mesh_id] = 0; _queue_or_build(node, mesh_id, collider_id)
	elif mesh_loaded[mesh_id] == 0 and mesh_state[base + MESH_JOB] == 0:
		_queue_or_build(node, mesh_id, collider_id)

func _queue_or_build(node: RefCounted, mesh_id: int, collider_id: int) -> void:
	if synchronous_mode: _build_sync(node, mesh_id, collider_id); return
	var base: int = mesh_id * 3
	if mesh_state[base + MESH_JOB] > 0 or staging_free.is_empty(): return
	var staging_id: int = staging_free.pop_back()
	var args: Array = staging_args[staging_id]
	args[0] = mesh_id; args[1] = mesh_state[base + MESH_GENERATION]; args[2] = staging_id
	args[3] = node.face_index; args[4] = node.lod_level; args[5] = node.uv_min; args[6] = node.uv_max
	args[7] = planet_manager.planet_radius; args[8] = seed_base + node.face_index * seed_face_stride
	args[9] = noise_frequency; args[10] = noise_amplitude; args[11] = collider_id != -1
	var job_id: int = task_scheduler.submit_job(_build_job_callable, args)
	if job_id <= 0: _return_staging(staging_id); return
	var job_base: int = (job_id & 63) * 4
	job_state[job_base + JOB_ID] = job_id; job_state[job_base + JOB_MESH] = mesh_id
	job_state[job_base + JOB_GENERATION] = mesh_state[base + MESH_GENERATION]
	job_state[job_base + JOB_STAGING] = staging_id
	mesh_state[base + MESH_JOB] = job_id; pending_jobs += 1; queued_job_count += 1

func _build_sync(node: RefCounted, mesh_id: int, collider_id: int) -> void:
	var seed_val: int = seed_base + node.face_index * seed_face_stride
	if compute_dispatcher != null:
		compute_dispatcher.dispatch_chunk(node.face_index, node.lod_level, node.uv_min, node.uv_max, planet_manager.planet_radius, seed_val, noise_frequency, noise_amplitude, _chunk_pool.get_mesh(mesh_id), 0)
	else:
		TerrainMeshBuilder.build_chunk_mesh(_chunk_pool.get_mesh(mesh_id), node.face_index, node.lod_level, node.uv_min, node.uv_max, planet_manager.planet_radius, seed_val, noise_frequency, noise_amplitude, 0)
	var faces: PackedVector3Array = EMPTY_FACES
	if collider_id != -1: faces = TerrainMeshBuilder.get_collider_faces(0)
	_apply_completed(node, mesh_id, collider_id, faces)

func _build_chunk_job(_mesh_id: int, _generation: int, staging_id: int, face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float, seed_val: int, freq: float, amp: float, has_collider: bool) -> bool:
	TerrainMeshBuilder.build_chunk_buffers(face_index, lod_level, uv_min, uv_max, planet_radius, seed_val, freq, amp, staging_arrays[staging_id], staging_faces[staging_id], has_collider, staging_id)
	return has_collider

func _on_job_completed(job_id: int, _result: Variant) -> void:
	var job_base: int = (job_id & 63) * 4
	if job_state[job_base + JOB_ID] != job_id: return
	var mesh_id: int = job_state[job_base + JOB_MESH]; var generation: int = job_state[job_base + JOB_GENERATION]
	var staging_id: int = job_state[job_base + JOB_STAGING]
	task_scheduler.reclaim_job(job_id)
	job_state[job_base + JOB_ID] = 0; job_state[job_base + JOB_MESH] = -1; job_state[job_base + JOB_STAGING] = -1
	pending_jobs = maxi(pending_jobs - 1, 0)
	if mesh_id < 0 or mesh_id >= VISUAL_POOL_SIZE: _return_staging(staging_id); return
	var base: int = mesh_id * 3; mesh_state[base + MESH_JOB] = 0; var node: RefCounted = mesh_owners[mesh_id]
	if node == null or mesh_state[base + MESH_GENERATION] != generation or not node.is_leaf: _return_staging(staging_id); return
	var target: ArrayMesh = _chunk_pool.get_mesh(mesh_id); target.clear_surfaces()
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, staging_arrays[staging_id])
	var collider_id: int = mesh_state[base + MESH_COLLIDER]
	var faces: PackedVector3Array = staging_faces[staging_id] if collider_id != -1 else EMPTY_FACES
	_apply_completed(node, mesh_id, collider_id, faces)
	_return_staging(staging_id)

func _apply_completed(node: RefCounted, mesh_id: int, collider_id: int, faces: PackedVector3Array) -> void:
	var origin: Vector3 = TerrainMeshBuilder.get_chunk_origin(node.face_index, node.uv_min, planet_manager.planet_radius)
	visuals[mesh_id].position = origin; visuals[mesh_id].visible = true
	if collider_id != -1:
		_collider_pool.set_collider_origin(collider_id, origin); _collider_pool.update_collider_faces(collider_id, faces)
	mesh_loaded[mesh_id] = 1

func _cancel_slot_job(mesh_id: int) -> void:
	var base: int = mesh_id * 3; var job_id: int = mesh_state[base + MESH_JOB]
	if job_id <= 0: return
	var job_base: int = (job_id & 63) * 4
	var staging_id: int = job_state[job_base + JOB_STAGING]
	if task_scheduler.cancel_job(job_id, true):
		cancelled_job_count += 1
		if retired_count < JOB_CAPACITY: retired_jobs[retired_count] = job_id; retired_staging[retired_count] = staging_id; retired_count += 1
	elif task_scheduler.reclaim_job(job_id): _return_staging(staging_id)
	job_state[job_base + JOB_ID] = 0; job_state[job_base + JOB_MESH] = -1; job_state[job_base + JOB_GENERATION] = 0; job_state[job_base + JOB_STAGING] = -1
	mesh_state[base + MESH_JOB] = 0; pending_jobs = maxi(pending_jobs - 1, 0)

func _release_retired_staging() -> void:
	var write_idx: int = 0
	for i in range(retired_count):
		var job_id: int = retired_jobs[i]
		if task_scheduler.get_job_status(job_id) == ChunkTaskScheduler.STATUS_EMPTY: _return_staging(retired_staging[i])
		else: retired_jobs[write_idx] = job_id; retired_staging[write_idx] = retired_staging[i]; write_idx += 1
	retired_count = write_idx

func _return_staging(staging_id: int) -> void:
	if staging_id >= 0 and staging_id < JOB_CAPACITY: staging_free.push_back(staging_id)

func _drain_jobs() -> void:
	if task_scheduler == null: return
	for job_base in range(0, JOB_CAPACITY * 4, 4):
		var job_id: int = job_state[job_base + JOB_ID]
		if job_id > 0 and task_scheduler.cancel_job(job_id, true): cancelled_job_count += 1
	for guard in range(5000):
		if not _has_running_jobs(): break
		OS.delay_usec(100)
	task_scheduler.poll()
	for job_base in range(0, JOB_CAPACITY * 4, 4):
		if job_state[job_base + JOB_ID] > 0: _return_staging(job_state[job_base + JOB_STAGING])
	for i in range(retired_count): _return_staging(retired_staging[i])
	retired_count = 0; job_state.fill(-1)
	for i in range(VISUAL_POOL_SIZE): mesh_state[i * 3 + MESH_JOB] = 0
	pending_jobs = 0

func _has_running_jobs() -> bool:
	for job_base in range(0, JOB_CAPACITY * 4, 4):
		var job_id: int = job_state[job_base + JOB_ID]
		if job_id > 0 and task_scheduler.get_job_status(job_id) == ChunkTaskScheduler.STATUS_RUNNING: return true
	for i in range(retired_count):
		if task_scheduler.get_job_status(retired_jobs[i]) == ChunkTaskScheduler.STATUS_RUNNING: return true
	return false

func _reset_slot(mesh_id: int) -> void:
	_cancel_slot_job(mesh_id)
	visuals[mesh_id].visible = false; visuals[mesh_id].position = Vector3.ZERO
	if _chunk_pool != null: _chunk_pool.get_mesh(mesh_id).clear_surfaces()
	mesh_owners[mesh_id] = null; mesh_state[mesh_id * 3 + MESH_COLLIDER] = -1
	mesh_state[mesh_id * 3 + MESH_JOB] = 0; mesh_loaded[mesh_id] = 0

func rebase_origin(offset: Vector3) -> void:
	if not is_instance_valid(planet_manager) or offset == Vector3.ZERO: return
	var target_origin: Vector3 = planet_manager.planet_center_offset
	if target_origin == (global_position if is_inside_tree() else position): target_origin -= offset
	_set_planet_origin(target_origin)

func _sync_planet_origin() -> void: if is_instance_valid(planet_manager): _set_planet_origin(planet_manager.planet_center_offset)

func _set_planet_origin(origin: Vector3) -> void:
	if is_inside_tree(): global_position = origin
	else: position = origin

func get_visual(mesh_id: int) -> MeshInstance3D: return visuals[mesh_id] if mesh_id >= 0 and mesh_id < VISUAL_POOL_SIZE else null
func get_active_visual_count() -> int:
	var count: int = 0; for i in range(VISUAL_POOL_SIZE): count += int(visuals[i].visible)
	return count
func get_orphan_mesh_count() -> int:
	var count: int = 0; for i in range(VISUAL_POOL_SIZE): count += int(mesh_loaded[i] != 0 and mesh_seen[i] == 0)
	return count

func destroy() -> void:
	if not synchronous_mode: _drain_jobs()
	if compute_dispatcher != null: compute_dispatcher.shutdown(); compute_dispatcher = null
	if task_scheduler != null:
		if task_scheduler.job_completed.is_connected(_on_job_completed): task_scheduler.job_completed.disconnect(_on_job_completed)
		if task_scheduler.get_parent() == self: task_scheduler.shutdown(); remove_child(task_scheduler); task_scheduler.free()
	task_scheduler = null
	for i in range(VISUAL_POOL_SIZE): _reset_slot(i); remove_child(visuals[i]); visuals[i].free()
	visuals.clear(); mesh_owners.clear(); mesh_state.clear(); mesh_loaded.clear()
	mesh_seen.clear(); job_state.clear(); staging_arrays.clear(); staging_faces.clear()
	staging_args.clear(); staging_free.clear(); retired_jobs.clear(); retired_staging.clear()
	planet_manager = null; _chunk_pool = null; _collider_pool = null
