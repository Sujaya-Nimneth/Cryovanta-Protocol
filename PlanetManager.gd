class_name PlanetManager
extends Node3D

## Coordinates 6 Cube-Face Quadtrees, ChunkPoolManager, and ColliderPoolManager.
## Follows rules.md: script length <= 250 lines, 0 runtime allocation in update loops.

@export var planet_radius: float = 100_000.0 # 100 km default radius
@export var max_lod: int = 5
@export var split_ratio: float = 2.2
@export var hysteresis: float = 1.35
@export var origin_rebase_threshold: float = 2000.0

const SECTOR_SIZE: float = 2000.0

var chunk_pool: ChunkPoolManager = null
var collider_pool: ColliderPoolManager = null
var face_roots: Array[QuadtreeNode] = []
var planet_center_offset: Vector3 = Vector3.ZERO
var floating_origin_offset: Vector3 = Vector3.ZERO
var planet_center_sector: Vector3i = Vector3i.ZERO
var planet_center_local: Vector3 = Vector3.ZERO

func _init() -> void:
	init_planet()

func init_planet() -> void:
	if collider_pool:
		collider_pool.clear()
		if collider_pool.get_parent() == self:
			remove_child(collider_pool)
		collider_pool.free()
		collider_pool = null
	if chunk_pool:
		chunk_pool.clear()
		chunk_pool = null
	QuadtreeNode.init_pool()
	chunk_pool = ChunkPoolManager.new()
	collider_pool = ColliderPoolManager.new()
	add_child(collider_pool)
	face_roots.clear()
	face_roots.resize(6)
	planet_center_offset = Vector3.ZERO
	floating_origin_offset = Vector3.ZERO
	planet_center_sector = Vector3i.ZERO
	planet_center_local = Vector3.ZERO
	
	# Initialize 6 cube face root nodes at LOD 0
	for face_idx in range(6):
		var root: QuadtreeNode = QuadtreeNode.acquire_node()
		root.init_node(
			face_idx,
			0,
			Vector2(-1.0, -1.0),
			Vector2(1.0, 1.0),
			null,
			planet_radius
		)
		root.mesh_id = chunk_pool.acquire_mesh(root)
		if collider_pool and root.lod_level >= max_lod - 1:
			root.collider_id = collider_pool.acquire_collider(root)
		face_roots[face_idx] = root

## Rebases planet coordinates by subtracting the offset from planet_center_offset.
func rebase_origin(offset: Vector3) -> void:
	planet_center_offset -= offset
	planet_center_local -= offset
	var sx: int = int(floor(planet_center_local.x / SECTOR_SIZE))
	var sy: int = int(floor(planet_center_local.y / SECTOR_SIZE))
	var sz: int = int(floor(planet_center_local.z / SECTOR_SIZE))
	if sx != 0 or sy != 0 or sz != 0:
		var s_vec: Vector3i = Vector3i(sx, sy, sz)
		planet_center_sector += s_vec
		planet_center_local -= Vector3(s_vec) * SECTOR_SIZE
	
	floating_origin_offset = planet_center_offset
	if is_inside_tree():
		global_position = planet_center_offset
	else:
		position = planet_center_offset

## Updates LOD across all 6 cube faces according to camera position relative to planet center.
## Strictly zero runtime allocation during update.
func update_camera(camera_pos: Vector3) -> void:
	var relative_cam_pos: Vector3 = camera_pos - planet_center_offset
	for face_idx in range(6):
		face_roots[face_idx].evaluate_lod(
			relative_cam_pos,
			chunk_pool,
			max_lod,
			planet_radius,
			split_ratio,
			hysteresis,
			collider_pool
		)

## Collects all active leaf nodes across the entire planet
func get_all_leaves() -> Array[QuadtreeNode]:
	var leaves: Array[QuadtreeNode] = []
	for face_idx in range(6):
		face_roots[face_idx].collect_leaves(leaves)
	return leaves

## Counts total active nodes across all 6 faces
func get_total_active_nodes() -> int:
	var total: int = 0
	for face_idx in range(6):
		total += face_roots[face_idx].count_nodes()
	return total

## Exhaustive structural audit:
## 1. Verifies 0 orphan nodes across entire pool
## 2. Verifies bidirectional parent-child integrity
## 3. Verifies exactly 1 mesh per active leaf and 0 meshes for non-leaves
## 4. Verifies pool active meshes == leaf node count
## 5. Verifies active colliders == leaf chunks at lod >= max_lod - 1 and 0 orphan colliders
func audit_system() -> Dictionary:
	var errors: Array[String] = []
	var visited_in_tree: Dictionary = {}
	var leaf_count: int = 0
	var expected_colliders: int = 0
	
	for face_idx in range(6):
		var root: QuadtreeNode = face_roots[face_idx]
		_audit_node_recursive(root, null, visited_in_tree, errors)
	
	for node in visited_in_tree.keys():
		if node.is_leaf:
			leaf_count += 1
			if node.mesh_id < 0 or node.mesh_id >= ChunkPoolManager.POOL_SIZE:
				errors.append("Leaf node on face %d has invalid mesh_id: %d" % [node.face_index, node.mesh_id])
			if node.lod_level >= max_lod - 1:
				expected_colliders += 1
				if collider_pool:
					if node.collider_id < 0 or node.collider_id >= ColliderPoolManager.POOL_SIZE:
						errors.append("Leaf node (face %d LOD %d) has invalid collider_id: %d" % [node.face_index, node.lod_level, node.collider_id])
					elif not collider_pool.is_in_use[node.collider_id]:
						errors.append("Leaf collider_id %d not marked in_use" % node.collider_id)
					elif collider_pool.collider_owners[node.collider_id] != node:
						errors.append("Leaf collider_id %d owner mismatch" % node.collider_id)
			else:
				if node.collider_id != -1:
					errors.append("Low-LOD leaf (face %d LOD %d) holds collider_id: %d" % [node.face_index, node.lod_level, node.collider_id])
		else:
			if node.mesh_id != -1:
				errors.append("Internal non-leaf node holds mesh_id: %d" % node.mesh_id)
			if node.collider_id != -1:
				errors.append("Internal non-leaf node holds collider_id: %d" % node.collider_id)
	
	if chunk_pool.get_active_count() != leaf_count:
		errors.append("ChunkPool active (%d) != leaf count (%d)" % [
			chunk_pool.get_active_count(), leaf_count
		])
	
	if collider_pool:
		if collider_pool.get_active_count() != expected_colliders:
			errors.append("ColliderPool active (%d) != expected high-LOD leaves (%d)" % [
				collider_pool.get_active_count(), expected_colliders
			])
		var col_audit: Dictionary = collider_pool.verify_integrity()
		if not col_audit["is_valid"]:
			errors.append("ColliderPool integrity errors: %s" % str(col_audit["errors"]))
		for cid in range(ColliderPoolManager.POOL_SIZE):
			if collider_pool.is_in_use[cid]:
				var c_owner = collider_pool.collider_owners[cid]
				if c_owner == null or not visited_in_tree.has(c_owner) or not c_owner.is_leaf or c_owner.collider_id != cid:
					errors.append("Orphan collider slot %d detected!" % cid)
	
	var orphan_count: int = 0
	var all_pool_nodes: Array[QuadtreeNode] = QuadtreeNode.get_all_pool_nodes()
	for pool_node in all_pool_nodes:
		if pool_node.is_active:
			if not visited_in_tree.has(pool_node):
				orphan_count += 1
				errors.append("Orphan node detected: active in pool but unreachable from roots!")
		else:
			if pool_node.parent != null:
				orphan_count += 1
				errors.append("Inactive node retains non-null parent!")
			if not pool_node.children.is_empty():
				orphan_count += 1
				errors.append("Inactive node retains non-empty children!")
			if pool_node.mesh_id != -1:
				errors.append("Inactive node retains mesh_id: %d" % pool_node.mesh_id)
			if pool_node.collider_id != -1:
				orphan_count += 1
				errors.append("Inactive node retains collider_id: %d" % pool_node.collider_id)
	
	return {
		"is_valid": errors.is_empty() and orphan_count == 0,
		"orphan_count": orphan_count,
		"total_tree_nodes": visited_in_tree.size(),
		"leaf_nodes": leaf_count,
		"active_meshes": chunk_pool.get_active_count(),
		"free_meshes": chunk_pool.get_free_count(),
		"active_colliders": collider_pool.get_active_count() if collider_pool else 0,
		"free_colliders": collider_pool.get_free_count() if collider_pool else 0,
		"errors": errors
	}

func _audit_node_recursive(node: QuadtreeNode, expected_parent: QuadtreeNode, visited: Dictionary, errors: Array[String]) -> void:
	if not node:
		errors.append("Null node encountered in tree traversal")
		return
	if visited.has(node):
		errors.append("Cyclic reference detected in Quadtree at node on face %d" % node.face_index)
		return
	visited[node] = true
	
	if node.parent != expected_parent:
		errors.append("Parent mismatch on face %d LOD %d" % [node.face_index, node.lod_level])
	
	if not node.is_leaf:
		if node.children.size() != 4:
			errors.append("Non-leaf node has %d children (expected 4)" % node.children.size())
		for child in node.children:
			_audit_node_recursive(child, node, visited, errors)

## Full cleanup of meshes and pools to prevent memory/ObjectDB leaks
func destroy() -> void:
	for face_idx in range(6):
		if face_roots[face_idx]:
			face_roots[face_idx].force_merge(chunk_pool, collider_pool, max_lod)
			if face_roots[face_idx].mesh_id != -1:
				chunk_pool.release_mesh(face_roots[face_idx].mesh_id)
				face_roots[face_idx].mesh_id = -1
			if collider_pool and face_roots[face_idx].collider_id != -1:
				collider_pool.release_collider(face_roots[face_idx].collider_id)
				face_roots[face_idx].collider_id = -1
			QuadtreeNode.release_node(face_roots[face_idx])
			face_roots[face_idx] = null
	face_roots.clear()
	if chunk_pool:
		chunk_pool.clear()
		chunk_pool = null
	if collider_pool:
		collider_pool.clear()
		if collider_pool.get_parent() == self:
			remove_child(collider_pool)
		collider_pool.free()
		collider_pool = null
	QuadtreeNode.clear_pool()
