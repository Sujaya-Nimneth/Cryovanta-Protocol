class_name PlanetSurfaceMaterial
extends RefCounted

## Shared procedural cryo-terrain material for every streamed planet chunk.
## The Shader and ShaderMaterial are created once at startup.

const SHADER_CODE: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 planet_center_offset = vec3(0.0);
uniform float planet_radius = 100000.0;
uniform float max_elevation = 500.0;
uniform vec4 lowland_color : source_color = vec4(0.055, 0.13, 0.16, 1.0);
uniform vec4 slope_color : source_color = vec4(0.30, 0.38, 0.40, 1.0);
uniform vec4 highland_ice_color : source_color = vec4(0.78, 0.91, 0.95, 1.0);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 radial = normalize(world_position - planet_center_offset);
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float elevation = clamp((length(world_position - planet_center_offset) - planet_radius) / max(max_elevation, 0.001), 0.0, 1.0);
	float slope = clamp(1.0 - dot(world_normal, radial), 0.0, 1.0);
	vec3 rock = mix(lowland_color.rgb, slope_color.rgb, smoothstep(0.08, 0.55, slope));
	vec3 color = mix(rock, highland_ice_color.rgb, smoothstep(0.48, 0.92, elevation + slope * 0.28));
	ALBEDO = color;
	ROUGHNESS = mix(0.96, 0.72, elevation);
	SPECULAR = 0.22;
}
"""

var shader: Shader = null
var material: ShaderMaterial = null
var planet_center_offset: Vector3 = Vector3.ZERO
var planet_radius: float = 100_000.0
var max_elevation: float = 500.0
var lowland_color: Color = Color(0.055, 0.13, 0.16, 1.0)
var slope_color: Color = Color(0.30, 0.38, 0.40, 1.0)
var highland_ice_color: Color = Color(0.78, 0.91, 0.95, 1.0)
var _planet_manager: Node = null

func _init() -> void:
	shader = Shader.new()
	shader.code = SHADER_CODE
	material = ShaderMaterial.new()
	material.shader = shader
	_sync_uniforms()

func apply_to_streamer(streamer: PlanetStreamer) -> void:
	if streamer == null:
		return
	for mesh_id in range(PlanetStreamer.VISUAL_POOL_SIZE):
		streamer.visuals[mesh_id].material_override = material

func update_planet_center(center: Vector3) -> void:
	planet_center_offset = center
	material.set_shader_parameter("planet_center_offset", planet_center_offset)

func update_planet_center_From_manager(manager_or_offset: Variant = null, manager: Node = null) -> void:
	if manager_or_offset is Object:
		_planet_manager = manager_or_offset
	elif manager != null:
		_planet_manager = manager
	if not is_instance_valid(_planet_manager):
		return
	var active_manager: Node = _planet_manager
	if "planet_center_offset" in active_manager:
		update_planet_center(active_manager.planet_center_offset)
	if "planet_radius" in active_manager:
		planet_radius = active_manager.planet_radius
		material.set_shader_parameter("planet_radius", planet_radius)

func set_terrain_palette(lowland: Color, slope: Color, ice: Color) -> void:
	lowland_color = lowland
	slope_color = slope
	highland_ice_color = ice
	_sync_uniforms()

func _sync_uniforms() -> void:
	material.set_shader_parameter("planet_center_offset", planet_center_offset)
	material.set_shader_parameter("planet_radius", planet_radius)
	material.set_shader_parameter("max_elevation", max_elevation)
	material.set_shader_parameter("lowland_color", lowland_color)
	material.set_shader_parameter("slope_color", slope_color)
	material.set_shader_parameter("highland_ice_color", highland_ice_color)
