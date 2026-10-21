class_name QuadtreeNode
extends RefCounted

## Pure data structure managing Cube-Sphere Quadtree subdivision based on camera distance.
## Conforms to .antigravity/rules.md:
## - Script length < 250 lines
## - Zero runtime allocation via pre-allocated node pooling
## - Recycles ArrayMesh via ChunkPoolManager without memory leaks or orphan nodes

# ==============================================================================
# Static Pre-allocated Node Pool (Zero runtime allocations in _process)
# ==============================================================================
const POOL_CAPACITY: int = 512
static var _pool: Array[QuadtreeNode] = []
static var _free_stack: Array[QuadtreeNode] = []
static var _pool_ready: bool = false
static var _active_count: int = 0

static func init_pool() -> void:
	if _pool_ready:
		return
	_pool.resize(POOL_CAPACITY)
	_free_stack.clear()
	for i in range(POOL_CAPACITY):
		var n: QuadtreeNode = QuadtreeNode.new()
		n.is_active = false
		_pool[i] = n
		_free_stack.push_back(n)
	_active_count = 0
	_pool_ready = true

static func acquire_node() -> QuadtreeNode:
	if not _pool_ready:
		init_pool()
	if _free_stack.is_empty():
		push_error("QuadtreeNode pool exhausted!")
		return null
	var node: QuadtreeNode = _free_stack.pop_back()
	node.is_active = true
	_active_count += 1
	return node

static func release_node(node: QuadtreeNode) -> void:
	if not node or not node.is_active:
		return
	node.is_active = false
	node.parent = null
	node.children.clear()
	node.mesh_id = -1
	node.collider_id = -1
	_free_stack.push_back(node)
	_active_count -= 1

static func get_active_node_count() -> int:
	return _active_count

static func get_pool_free_count() -> int:
	return _free_stack.size()

static func get_all_pool_nodes() -> Array[QuadtreeNode]:
	return _pool

static func clear_pool() -> void:
	for i in range(_pool.size()):
		if _pool[i]:
			_pool[i].parent = null
			_pool[i].children.clear()
			_pool[i] = null
	_pool.clear()
	_free_stack.clear()
	_active_count = 0
	_pool_ready = false

# ==============================================================================
# Instance Data
# ==============================================================================
var face_index: int = 0
var lod_level: int = 0
var uv_min: Vector2 = Vector2(-1.0, -1.0)
var uv_max: Vector2 = Vector2(1.0, 1.0)
var center_pos: Vector3 = Vector3.ZERO
var bounding_radius: float = 0.0

var parent: QuadtreeNode = null
var children: Array[QuadtreeNode] = []
var is_leaf: bool = true
var mesh_id: int = -1
var collider_id: int = -1
var is_active: bool = false

func init_node(p_face: int, p_lod: int, p_min: Vector2, p_max: Vector2, p_parent: QuadtreeNode, radius: float) -> void:
	face_index = p_face
	lod_level = p_lod
	uv_min = p_min
	uv_max = p_max
	parent = p_parent
	children.clear()
	is_leaf = true
	mesh_id = -1
	collider_id = -1
	
	center_pos = PlanetMath.get_chunk_center(face_index, uv_min, uv_max, radius)
	bounding_radius = PlanetMath.get_chunk_radius(face_index, uv_min, uv_max, center_pos, radius)

# ==============================================================================
# Subdivision & Merging
# ==============================================================================
func evaluate_lod(cam_pos: Vector3, pool: ChunkPoolManager, max_lod: int, radius: float, split_ratio: float, hysteresis: float, col_pool: ColliderPoolManager = null) -> void:
	var dist: float = cam_pos.distance_to(center_pos)
	var split_dist: float = bounding_radius * split_ratio
	
	if is_leaf:
		if lod_level < max_lod and dist < split_dist:
			var col_needed: int = 0
			if col_pool != null and (lod_level + 1 >= max_lod - 1):
				col_needed = 3 if (collider_id != -1) else 4
			var can_col: bool = (col_pool == null or col_needed == 0 or col_pool.has_available(col_needed))
			if pool.has_available(3) and get_pool_free_count() >= 4 and can_col:
				split(pool, radius, col_pool, max_lod)
	else:
		var merge_dist: float = split_dist * hysteresis
		if dist > merge_dist:
			force_merge(pool, col_pool, max_lod)
		else:
			for i in range(children.size()):
				children[i].evaluate_lod(cam_pos, pool, max_lod, radius, split_ratio, hysteresis, col_pool)

func split(pool: ChunkPoolManager, radius: float, col_pool: ColliderPoolManager = null, max_lod: int = 5) -> bool:
	var col_needed: int = 0
	if col_pool != null and (lod_level + 1 >= max_lod - 1):
		col_needed = 3 if (collider_id != -1) else 4
	if not is_leaf or not pool.has_available(3) or get_pool_free_count() < 4:
		return false
	if col_pool != null and col_needed > 0 and not col_pool.has_available(col_needed):
		return false
	
	var old_mesh_id: int = mesh_id
	mesh_id = -1
	if old_mesh_id != -1:
		pool.release_mesh(old_mesh_id)
	var old_col_id: int = collider_id
	collider_id = -1
	if col_pool and old_col_id != -1:
		col_pool.release_collider(old_col_id)
	
	var mid: Vector2 = (uv_min + uv_max) * 0.5
	children.resize(4)
	_create_child(0, pool, radius, col_pool, max_lod, uv_min, mid)
	_create_child(1, pool, radius, col_pool, max_lod, Vector2(mid.x, uv_min.y), Vector2(uv_max.x, mid.y))
	_create_child(2, pool, radius, col_pool, max_lod, Vector2(uv_min.x, mid.y), Vector2(mid.x, uv_max.y))
	_create_child(3, pool, radius, col_pool, max_lod, mid, uv_max)
	
	is_leaf = false
	return true

func _create_child(idx: int, pool: ChunkPoolManager, radius: float, col_pool: ColliderPoolManager, max_lod: int, c_min: Vector2, c_max: Vector2) -> void:
	var c: QuadtreeNode = acquire_node()
	c.init_node(face_index, lod_level + 1, c_min, c_max, self, radius)
	c.mesh_id = pool.acquire_mesh(c)
	if col_pool and (c.lod_level >= max_lod - 1):
		c.collider_id = col_pool.acquire_collider(c)
	children[idx] = c

func merge(pool: ChunkPoolManager, col_pool: ColliderPoolManager = null, max_lod: int = 5) -> bool:
	if is_leaf:
		return false
	
	for child in children:
		if not child.is_leaf:
			child.force_merge(pool, col_pool, max_lod)
		if child.mesh_id != -1:
			pool.release_mesh(child.mesh_id)
			child.mesh_id = -1
		if col_pool and child.collider_id != -1:
			col_pool.release_collider(child.collider_id)
			child.collider_id = -1
		release_node(child)
	
	children.clear()
	is_leaf = true
	mesh_id = pool.acquire_mesh(self)
	if col_pool and (lod_level >= max_lod - 1):
		collider_id = col_pool.acquire_collider(self)
	return true

func force_merge(pool: ChunkPoolManager, col_pool: ColliderPoolManager = null, max_lod: int = 5) -> void:
	if is_leaf:
		return
	for child in children:
		if not child.is_leaf:
			child.force_merge(pool, col_pool, max_lod)
	merge(pool, col_pool, max_lod)

# ==============================================================================
# Queries & Traversal
# ==============================================================================
func collect_leaves(out: Array[QuadtreeNode]) -> void:
	if is_leaf:
		out.append(self)
	else:
		for child in children:
			child.collect_leaves(out)

func count_nodes() -> int:
	var total: int = 1
	for child in children:
		total += child.count_nodes()
	return total
