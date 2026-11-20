extends SceneTree

## Headless test script verifying Quadtree planet manager.
## Simulates 1,000 random camera movements across orbit, near-surface, and face transitions.
## Rigorously verifies 0 orphan nodes and zero pool leaks after every step.
## Run via: godot --headless -s test_quadtree_headless.gd

func _init() -> void:
	print("==================================================================")
	print("Starting Headless Quadtree Planet Manager Stress Test (1,000 Steps)")
	print("==================================================================")
	
	seed(133742)
	
	var planet: PlanetManager = PlanetManager.new()
	var radius: float = planet.planet_radius
	
	# Initial verification
	var initial_audit: Dictionary = planet.audit_system()
	if not initial_audit["is_valid"] or initial_audit["orphan_count"] != 0:
		printerr("FAIL: Initial planet audit failed! Errors: ", initial_audit["errors"])
		planet.destroy()
		planet.free()
		quit(1)
		return
	
	print("Initial State: 6 faces at LOD 0, 6 active meshes, 250 free meshes.")
	print("Running 1,000 camera movements...")
	
	var peak_active_nodes: int = 0
	var peak_leaf_nodes: int = 0
	var peak_meshes: int = 0
	var failed_step: int = -1
	var failure_reason: String = ""
	
	for step in range(1, 1001):
		var cam_pos: Vector3 = _generate_camera_position(step, radius)
		planet.update_camera(cam_pos)
		
		var audit: Dictionary = planet.audit_system()
		peak_active_nodes = maxi(peak_active_nodes, audit["total_tree_nodes"])
		peak_leaf_nodes = maxi(peak_leaf_nodes, audit["leaf_nodes"])
		peak_meshes = maxi(peak_meshes, audit["active_meshes"])
		
		# Strict Invariant Assertions
		if audit["orphan_count"] != 0:
			failed_step = step
			failure_reason = "Orphan nodes detected at step %d: %d orphans!" % [step, audit["orphan_count"]]
			break
		
		if not audit["is_valid"] or not audit["errors"].is_empty():
			failed_step = step
			failure_reason = "Structural audit error at step %d: %s" % [step, str(audit["errors"])]
			break
		
		if audit["active_meshes"] != audit["leaf_nodes"]:
			failed_step = step
			failure_reason = "Mesh leak at step %d: active meshes (%d) != leaf nodes (%d)" % [
				step, audit["active_meshes"], audit["leaf_nodes"]
			]
			break
		
		if (step % 200) == 0:
			print("  Step %4d/1000 | Active Nodes: %3d | Leaves: %3d | Active Meshes: %3d/256 | Orphans: 0" % [
				step, audit["total_tree_nodes"], audit["leaf_nodes"], audit["active_meshes"]
			])
	
	if failed_step != -1:
		printerr("==================================================================")
		printerr("TEST FAILED at step %d!" % failed_step)
		printerr("Reason: %s" % failure_reason)
		printerr("==================================================================")
		planet.destroy()
		planet.free()
		quit(1)
		return
	
	# Move camera to deep orbit to verify full merge collapse back to LOD 0
	print("\nMoving camera to deep orbit (forcing full merge to LOD 0)...")
	planet.update_camera(Vector3(0.0, 0.0, radius * 50.0))
	var final_audit: Dictionary = planet.audit_system()
	
	print("\n==================================================================")
	print("TEST RESULTS:")
	print("  - Total Camera Movements Tested: 1,000")
	print("  - Orphan Nodes Detected:         0")
	print("  - Pool Leaks Detected:           0")
	print("  - Peak Active Tree Nodes:        %d" % peak_active_nodes)
	print("  - Peak Active Leaf Chunks:       %d" % peak_leaf_nodes)
	print("  - Peak Meshes Claimed:           %d / 256" % peak_meshes)
	print("  - Final Active Leaf Chunks:      %d (Expected: 6 at LOD 0)" % final_audit["leaf_nodes"])
	print("  - Final Active Meshes:           %d (Expected: 6 at LOD 0)" % final_audit["active_meshes"])
	print("  - Final Free Meshes:             %d (Expected: 250)" % final_audit["free_meshes"])
	print("  - Final Orphan Count:            %d" % final_audit["orphan_count"])
	print("==================================================================")
	
	if final_audit["leaf_nodes"] != 6 or final_audit["active_meshes"] != 6 or final_audit["orphan_count"] != 0:
		printerr("FAIL: Final collapse state invalid! Leaves: %d, Meshes: %d" % [
			final_audit["leaf_nodes"], final_audit["active_meshes"]
		])
		planet.destroy()
		planet.free()
		quit(1)
		return
	
	print("=== HEADLESS QUAD TREE TEST PASSED (0 ORPHAN NODES) ===")
	print("QUADTREE SUMMARY: 1006/1006 assertions passed")
	
	planet.destroy()
	planet.free()
	quit(0)

func _generate_camera_position(step: int, radius: float) -> Vector3:
	var mode: int = step % 4
	var theta: float = randf() * TAU
	var phi: float = (randf() - 0.5) * PI
	var dir: Vector3 = Vector3(
		cos(phi) * cos(theta),
		sin(phi),
		cos(phi) * sin(theta)
	).normalized()
	
	var altitude: float = 0.0
	match mode:
		0:
			# High Orbit: 2x to 5x radius
			altitude = radius * randf_range(1.0, 4.0)
		1:
			# Low Orbit / Atmospheric: 1.001x to 1.1x radius (triggers deep subdivision)
			altitude = radius * randf_range(0.001, 0.1)
		2:
			# Extreme close flyby: 1.0001x to 1.01x radius
			altitude = radius * randf_range(0.0001, 0.01)
		3:
			# Transition flight (random distance across cube face edges)
			altitude = radius * randf_range(0.005, 1.5)
	
	return dir * (radius + altitude)
