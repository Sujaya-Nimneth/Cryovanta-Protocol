extends Node3D

## Streams quadtree leaves into preallocated mesh/collider slots. Jobs drain before LOD mutation.

@export var auto_update: bool = false
@export var camera: Node3D = null
@export var seed_base: int = 1337
@export var seed_face_stride: int = 17
@export var noise_frequency: float = 0.002
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

var planet_manager: Node = null
var task_scheduler: Node = null
var visuals: Array[MeshInstance3D] = []
var mesh_owners: Array = []
var mesh_state: PackedInt64Array = PackedInt64Array()
var mesh_loaded: PackedByteArray = PackedByteArray()
var mesh_seen: PackedByteArray = PackedByteArray()
var job_state: PackedInt64Array = PackedInt64Array()
var staging_meshes: Array[ArrayMesh] = []
var staging_free: Array[int] = []
var pending_jobs: int = 0
var queued_job_count: int = 0
var cancelled_job_count: int = 0
var _chunk_pool: RefCounted = null
var _collider_pool: Node3D = null

func _init() -> void:
	visuals.resize(VISUAL_POOL_SIZE); mesh_owners.resize(VISUAL_POOL_SIZE); mesh_state.resize(VISUAL_POOL_SIZE * 3)
	job_state.resize(JOB_CAPACITY * 4); mesh_loaded.resize(VISUAL_POOL_SIZE); mesh_seen.resize(VISUAL_POOL_SIZE)
	staging_meshes.resize(JOB_CAPACITY); staging_free.resize(JOB_CAPACITY)
	for i in range(VISUAL_POOL_SIZE):
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "TerrainVisual_%d" % i; visual.visible = false
		add_child(visual); visuals[i] = visual; mesh_state[i * 3 + MESH_COLLIDER] = -1
	for i in range(JOB_CAPACITY):
		staging_meshes[i] = ArrayMesh.new(); staging_free[i] = JOB_CAPACITY - 1 - i

func setup(planet: Node, scheduler: Node = null, immediate: bool = false) -> void:
	planet_manager = planet; synchronous_mode = immediate
	TerrainMeshBuilder.init_builder()
	_chunk_pool = planet.chunk_pool
	_collider_pool = planet.collider_pool
	for i in range(VISUAL_POOL_SIZE):
		visuals[i].mesh = _chunk_pool.get_mesh(i)
	task_scheduler = scheduler if scheduler != null else ChunkTaskScheduler.new()
	if task_scheduler.get_parent() == null:
		add_child(task_scheduler)
	if not task_scheduler.job_completed.is_connected(_on_job_completed):
		task_scheduler.job_completed.connect(_on_job_completed)

func _process(_delta: float) -> void:
	if auto_update and is_instance_valid(camera):
		update_streamer(camera.global_position)

## Updates LOD, then synchronizes every active leaf with its pool slot.
func update_streamer(camera_pos: Vector3) -> void:
	if not is_instance_valid(planet_manager):
		return
	if not synchronous_mode:
		_drain_jobs()
	planet_manager.update_camera(camera_pos)
	_scan_leaves()

func _scan_leaves() -> void:
	mesh_seen.fill(0)
	for face_idx in range(6):
		_visit_leaf(planet_manager.face_roots[face_idx])
	for i in range(VISUAL_POOL_SIZE):
		if mesh_seen[i] == 0 and mesh_owners[i] != null:
			_reset_slot(i)

func _visit_leaf(node: RefCounted) -> void:
	if not node.is_leaf:
		for child in node.children:
			_visit_leaf(child)
		return
	var mesh_id: int = node.mesh_id
	if mesh_id < 0 or mesh_id >= VISUAL_POOL_SIZE:
		return
	mesh_seen[mesh_id] = 1
	var base: int = mesh_id * 3
	var collider_id: int = node.collider_id
	if mesh_owners[mesh_id] != node:
		_reset_slot(mesh_id); mesh_owners[mesh_id] = node
		mesh_state[base + MESH_GENERATION] += 1; mesh_state[base + MESH_COLLIDER] = collider_id
		_queue_or_build(node, mesh_id, collider_id)
	elif mesh_state[base + MESH_COLLIDER] != collider_id:
		mesh_state[base + MESH_COLLIDER] = collider_id
		mesh_loaded[mesh_id] = 0
		_queue_or_build(node, mesh_id, collider_id)
	elif mesh_loaded[mesh_id] == 0 and mesh_state[base + MESH_JOB] == 0:
		_queue_or_build(node, mesh_id, collider_id)

func _queue_or_build(node: RefCounted, mesh_id: int, collider_id: int) -> void:
	if synchronous_mode:
		_build_sync(node, mesh_id, collider_id)
		return
	var base: int = mesh_id * 3
	if staging_free.is_empty():
		return
	var staging_id: int = staging_free.pop_back()
	var args: Array = [
		mesh_id, mesh_state[base + MESH_GENERATION], staging_id, node.face_index,
		node.lod_level, node.uv_min, node.uv_max, planet_manager.planet_radius,
		seed_base + node.face_index * seed_face_stride, noise_frequency,
		noise_amplitude, collider_id != -1
	]
	var job_id: int = task_scheduler.submit_job(Callable(self, "_build_chunk_job"), args)
	if job_id <= 0:
		staging_free.push_back(staging_id)
		return
	var job_base: int = (job_id & 63) * 4
	job_state[job_base + JOB_ID] = job_id; job_state[job_base + JOB_MESH] = mesh_id
	job_state[job_base + JOB_GENERATION] = mesh_state[base + MESH_GENERATION]
	job_state[job_base + JOB_STAGING] = staging_id
	mesh_state[base + MESH_JOB] = job_id; pending_jobs += 1; queued_job_count += 1

func _build_sync(node: RefCounted, mesh_id: int, collider_id: int) -> void:
	TerrainMeshBuilder.build_chunk_mesh(_chunk_pool.get_mesh(mesh_id), node.face_index, node.lod_level, node.uv_min, node.uv_max, planet_manager.planet_radius, seed_base + node.face_index * seed_face_stride, noise_frequency, noise_amplitude, 0)
	var faces: PackedVector3Array = PackedVector3Array()
	if collider_id != -1:
		faces = TerrainMeshBuilder.get_collider_faces(0)
	_apply_completed(node, mesh_id, collider_id, faces)

func _build_chunk_job(_mesh_id: int, _generation: int, staging_id: int, face_index: int, lod_level: int, uv_min: Vector2, uv_max: Vector2, planet_radius: float, seed_val: int, freq: float, amp: float, has_collider: bool) -> PackedVector3Array:
	var worker_slot: int = ChunkTaskScheduler.get_current_worker_index()
	TerrainMeshBuilder.build_chunk_mesh(staging_meshes[staging_id], face_index, lod_level, uv_min, uv_max, planet_radius, seed_val, freq, amp, worker_slot)
	if has_collider:
		return TerrainMeshBuilder.get_collider_faces(worker_slot)
	return PackedVector3Array()

func _on_job_completed(job_id: int, result: Variant) -> void:
	var job_base: int = (job_id & 63) * 4
	if job_state[job_base + JOB_ID] != job_id:
		return
	var mesh_id: int = job_state[job_base + JOB_MESH]
	var generation: int = job_state[job_base + JOB_GENERATION]
	var staging_id: int = job_state[job_base + JOB_STAGING]
	job_state[job_base + JOB_ID] = 0; staging_free.push_back(staging_id)
	pending_jobs = maxi(pending_jobs - 1, 0)
	if mesh_id < 0 or mesh_id >= VISUAL_POOL_SIZE:
		return
	var base: int = mesh_id * 3
	mesh_state[base + MESH_JOB] = 0
	var node: RefCounted = mesh_owners[mesh_id]
	if node == null or mesh_state[base + MESH_GENERATION] != generation or not node.is_leaf:
		return
	var target: ArrayMesh = _chunk_pool.get_mesh(mesh_id)
	target.clear_surfaces()
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, staging_meshes[staging_id].surface_get_arrays(0))
	var faces: PackedVector3Array = result if result is PackedVector3Array else PackedVector3Array()
	_apply_completed(node, mesh_id, mesh_state[base + MESH_COLLIDER], faces)

func _apply_completed(node: RefCounted, mesh_id: int, collider_id: int, faces: PackedVector3Array) -> void:
	var origin: Vector3 = TerrainMeshBuilder.get_chunk_origin(node.face_index, node.uv_min, planet_manager.planet_radius)
	visuals[mesh_id].position = origin; visuals[mesh_id].visible = true
	if collider_id != -1:
		_collider_pool.set_collider_origin(collider_id, origin)
		_collider_pool.update_collider_faces(collider_id, faces)
	mesh_loaded[mesh_id] = 1

func _drain_jobs() -> void:
	if pending_jobs == 0:
		return
	for job_base in range(0, JOB_CAPACITY * 4, 4):
		var job_id: int = job_state[job_base + JOB_ID]
		if job_id <= 0:
			continue
		var status: int = task_scheduler.get_job_status(job_id)
		if status == ChunkTaskScheduler.STATUS_QUEUED or status == ChunkTaskScheduler.STATUS_RUNNING:
			if task_scheduler.cancel_job(job_id, true):
				cancelled_job_count += 1
	for guard in range(5000):
		if not _has_running_jobs():
			break
		OS.delay_usec(100)
	task_scheduler.poll()
	for job_base in range(0, JOB_CAPACITY * 4, 4):
		if job_state[job_base + JOB_ID] > 0 and job_state[job_base + JOB_STAGING] >= 0:
			staging_free.push_back(job_state[job_base + JOB_STAGING])
	job_state.fill(-1)
	for i in range(VISUAL_POOL_SIZE):
		mesh_state[i * 3 + MESH_JOB] = 0
	pending_jobs = 0

func _has_running_jobs() -> bool:
	for job_base in range(0, JOB_CAPACITY * 4, 4):
		var job_id: int = job_state[job_base + JOB_ID]
		if job_id > 0 and task_scheduler.get_job_status(job_id) == ChunkTaskScheduler.STATUS_RUNNING:
			return true
	return false

func _reset_slot(mesh_id: int) -> void:
	visuals[mesh_id].visible = false; visuals[mesh_id].position = Vector3.ZERO
	if _chunk_pool != null:
		_chunk_pool.get_mesh(mesh_id).clear_surfaces()
	mesh_owners[mesh_id] = null
	var base: int = mesh_id * 3
	mesh_state[base + MESH_COLLIDER] = -1
	mesh_state[base + MESH_JOB] = 0
	mesh_loaded[mesh_id] = 0

func get_visual(mesh_id: int) -> MeshInstance3D:
	return visuals[mesh_id] if mesh_id in range(VISUAL_POOL_SIZE) else null

func get_active_visual_count() -> int:
	var count: int = 0
	for i in range(VISUAL_POOL_SIZE):
		if visuals[i].visible:
			count += 1
	return count

func get_orphan_mesh_count() -> int:
	var count: int = 0
	for i in range(VISUAL_POOL_SIZE):
		if mesh_loaded[i] != 0 and mesh_seen[i] == 0:
			count += 1
	return count

func destroy() -> void:
	if not synchronous_mode:
		_drain_jobs()
	if task_scheduler != null:
		if task_scheduler.job_completed.is_connected(_on_job_completed):
			task_scheduler.job_completed.disconnect(_on_job_completed)
		if task_scheduler.get_parent() == self:
			task_scheduler.shutdown()
			remove_child(task_scheduler)
			task_scheduler.free()
	task_scheduler = null
	for i in range(VISUAL_POOL_SIZE):
		_reset_slot(i)
		remove_child(visuals[i])
		visuals[i].free()
	visuals.clear(); mesh_owners.clear(); mesh_state.clear(); mesh_loaded.clear()
	mesh_seen.clear(); job_state.clear(); staging_meshes.clear(); staging_free.clear()
	planet_manager = null; _chunk_pool = null
	_collider_pool = null
