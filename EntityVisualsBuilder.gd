class_name EntityVisualsBuilder
extends RefCounted

## Procedural 3D Visual Rig Builder & Shared Pool Resource Provider.
## Guarantees 0 runtime heap memory allocations during live flight updates.

# Shared Ship Visual Rig Materials
static var _hull_mat: StandardMaterial3D = null
static var _canopy_mat: StandardMaterial3D = null
static var _alloy_mat: StandardMaterial3D = null
static var _plume_mat: StandardMaterial3D = null

# Shared Combat Pool Resources (7 singletons)
static var _target_mesh: SphereMesh = null
static var _target_mat: StandardMaterial3D = null
static var _target_shape: SphereShape3D = null
static var _projectile_mesh: BoxMesh = null
static var _projectile_mat: StandardMaterial3D = null
static var _impact_mesh: SphereMesh = null
static var _impact_mat: StandardMaterial3D = null

static func get_target_mesh() -> SphereMesh:
	if _target_mesh == null:
		var m := SphereMesh.new()
		m.radius = 3.0; m.height = 6.0; m.radial_segments = 16; m.rings = 8
		_target_mesh = m
	return _target_mesh

static func get_target_material() -> StandardMaterial3D:
	if _target_mat == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.18, 0.1, 1.0)
		mat.emission_enabled = true; mat.emission = Color(1.0, 0.25, 0.08, 1.0)
		mat.emission_energy_multiplier = 2.0; mat.rim_enabled = true
		mat.rim = 0.8; mat.rim_tint = 0.5; mat.roughness = 0.35; mat.metallic = 0.6
		_target_mat = mat
	return _target_mat

static func get_target_shape() -> SphereShape3D:
	if _target_shape == null:
		var s := SphereShape3D.new()
		s.radius = 3.0
		_target_shape = s
	return _target_shape

static func get_projectile_mesh() -> BoxMesh:
	if _projectile_mesh == null:
		var m := BoxMesh.new(); m.size = Vector3.ONE
		_projectile_mesh = m
	return _projectile_mesh

static func get_projectile_material() -> StandardMaterial3D:
	if _projectile_mat == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.2, 0.9, 1.0, 1.0); mat.emission_enabled = true
		mat.emission = Color(0.2, 0.95, 1.0, 1.0); mat.emission_energy_multiplier = 4.0
		_projectile_mat = mat
	return _projectile_mat

static func get_impact_mesh() -> SphereMesh:
	if _impact_mesh == null:
		var m := SphereMesh.new()
		m.radius = 0.5; m.height = 1.0; m.radial_segments = 12; m.rings = 6
		_impact_mesh = m
	return _impact_mesh

static func get_impact_material() -> StandardMaterial3D:
	if _impact_mat == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.3, 0.9); mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.2, 1.0); mat.emission_energy_multiplier = 5.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_impact_mat = mat
	return _impact_mat

static func _init_ship_materials() -> void:
	if _hull_mat == null:
		var h := StandardMaterial3D.new()
		h.albedo_color = Color(0.22, 0.25, 0.3, 1.0); h.metallic = 0.75; h.roughness = 0.35
		_hull_mat = h
	if _canopy_mat == null:
		var c := StandardMaterial3D.new()
		c.albedo_color = Color(0.12, 0.36, 0.52, 0.85); c.metallic = 0.9; c.roughness = 0.12
		c.emission_enabled = true; c.emission = Color(0.12, 0.36, 0.52); c.emission_energy_multiplier = 1.2
		_canopy_mat = c
	if _alloy_mat == null:
		var a := StandardMaterial3D.new()
		a.albedo_color = Color(0.15, 0.15, 0.18, 1.0); a.metallic = 0.85; a.roughness = 0.4
		_alloy_mat = a
	if _plume_mat == null:
		var p := StandardMaterial3D.new()
		p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.albedo_color = Color(0.2, 0.85, 1.0, 0.95); p.emission_enabled = true
		p.emission = Color(0.2, 0.85, 1.0); p.emission_energy_multiplier = 4.0
		p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_plume_mat = p

static func _make_mesh_inst(p_name: String, p_mesh: Mesh, p_mat: Material, p_pos: Vector3, p_rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = p_name; mi.mesh = p_mesh; mi.material_override = p_mat
	mi.position = p_pos; mi.rotation = p_rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func build_ship_visual_rig(parent: Node3D = null) -> Node3D:
	_init_ship_materials()
	var rig := Node3D.new()
	rig.name = "ShipVisualRoot"

	# Fuselage, nosecone wedge, canopy
	var bm := BoxMesh.new(); bm.size = Vector3(1.2, 0.6, 3.2)
	rig.add_child(_make_mesh_inst("Fuselage", bm, _hull_mat, Vector3(0.0, 0.0, 0.2)))
	var pm := PrismMesh.new(); pm.size = Vector3(1.2, 1.8, 0.6)
	rig.add_child(_make_mesh_inst("NoseCone", pm, _hull_mat, Vector3(0.0, 0.0, -2.0), Vector3(-PI * 0.5, 0.0, 0.0)))
	var cm := BoxMesh.new(); cm.size = Vector3(0.65, 0.35, 1.4)
	rig.add_child(_make_mesh_inst("Canopy", cm, _canopy_mat, Vector3(0.0, 0.38, -0.6)))

	# Swept delta wings and vertical stabilizer
	var wm := BoxMesh.new(); wm.size = Vector3(1.8, 0.06, 2.2)
	rig.add_child(_make_mesh_inst("WingLeft", wm, _hull_mat, Vector3(-1.4, 0.0, 0.5), Vector3(-0.035, 0.314, -0.05)))
	rig.add_child(_make_mesh_inst("WingRight", wm, _hull_mat, Vector3(1.4, 0.0, 0.5), Vector3(-0.035, -0.314, 0.05)))
	var sm := BoxMesh.new(); sm.size = Vector3(0.08, 0.8, 1.4)
	rig.add_child(_make_mesh_inst("Stabilizer", sm, _alloy_mat, Vector3(0.0, 0.65, 1.0), Vector3(-0.26, 0.0, 0.0)))

	# Twin nozzles and thruster plumes
	var nm := CylinderMesh.new(); nm.top_radius = 0.22; nm.bottom_radius = 0.28; nm.height = 0.5
	rig.add_child(_make_mesh_inst("NozzleLeft", nm, _alloy_mat, Vector3(-0.42, 0.0, 1.85), Vector3(PI * 0.5, 0.0, 0.0)))
	rig.add_child(_make_mesh_inst("NozzleRight", nm, _alloy_mat, Vector3(0.42, 0.0, 1.85), Vector3(PI * 0.5, 0.0, 0.0)))

	var plm := SphereMesh.new(); plm.radius = 0.18; plm.height = 0.36
	var pl := _make_mesh_inst("PlumeLeft", plm, _plume_mat, Vector3(-0.42, 0.0, 2.1))
	pl.visible = false; rig.add_child(pl)
	var pr := _make_mesh_inst("PlumeRight", plm, _plume_mat, Vector3(0.42, 0.0, 2.1))
	pr.visible = false; rig.add_child(pr)
	rig.set_meta(&"plume_left", pl)
	rig.set_meta(&"plume_right", pr)

	if parent != null:
		parent.add_child(rig)
	return rig

static func update_flight_visuals(rig: Node3D, ship: Node3D) -> void:
	if rig == null or ship == null:
		return
	var roll_target: float = 0.0
	var pitch_target: float = 0.0
	if "torque_input" in ship:
		var ti: Vector3 = ship.torque_input
		roll_target -= ti.z * 0.25; pitch_target += ti.x * 0.12
	if "angular_velocity" in ship:
		var b: Basis = ship.global_transform.basis if ship.is_inside_tree() else ship.transform.basis
		var local_av: Vector3 = b.inverse() * ship.angular_velocity
		roll_target -= local_av.z * 0.08
	rig.rotation.z = clampf(roll_target, -0.35, 0.35)
	rig.rotation.x = clampf(pitch_target, -0.20, 0.20)

	var throttle: float = 0.0
	if "thrust_input" in ship:
		var ti: Vector3 = ship.thrust_input
		throttle = clampf(ti.z, 0.0, 1.0)
	var pl: Node3D = rig.get_meta(&"plume_left", null) as Node3D
	if pl == null:
		pl = rig.get_node_or_null("PlumeLeft") as Node3D
	if pl != null:
		pl.visible = throttle > 0.01; pl.scale.z = 0.3 + throttle * 1.5
	var pr: Node3D = rig.get_meta(&"plume_right", null) as Node3D
	if pr == null:
		pr = rig.get_node_or_null("PlumeRight") as Node3D
	if pr != null:
		pr.visible = throttle > 0.01; pr.scale.z = 0.3 + throttle * 1.5
