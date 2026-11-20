# Cryovanta Protocol — Art Bible & Visual Budget Specification

**Document Tier:** Standard Art Bible (Grounded in Observed Shipped Shaders & Procedural Geometry)  
**Target Renderer:** Godot 4.7.2 `Vulkan Mobile` (`mobile` rendering method, ETC2/ASTC)  
**Target Frame / Draw-Call / Memory Budget (`project.yaml`):** `120 FPS` (`8.333333 ms`), `<= 400` draw calls, `<= 1,024 MB` memory ceiling

---

## 1. Visual Identity Statement

**"Cryogenic Hard-SF Telemetry"** — razor-sharp procedural spacecraft geometry and luminous cyan/amber diegetic instruments cutting across dark sub-glacial basalt lowlands, weathered slate slopes, and sunlit glacial highlands.

## 2. Planetary Surface Material & Elevation Palette ([PlanetSurfaceMaterial.gd](../../PlanetSurfaceMaterial.gd))

- **Shader Mode:** `spatial`, `render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;` (`SPECULAR = 0.22`, `ROUGHNESS = mix(0.96, 0.72, elevation)`).
- **Signed Elevation & Slope Mapping:** Signed terrain elevation (`[-max_elevation, +max_elevation]`) remapped to `[0.0, 1.0]` via `* 0.5 + 0.5`, with rock-to-slope blend `smoothstep(0.03, 0.38, slope)` and glacier highland blend `smoothstep(0.48, 0.92, elevation + slope * 0.28)`:

| Surface Band | Linear/Shader Color (`Color(r, g, b, a)`) | Role |
| :--- | :--- | :--- |
| **`lowland_color`** | `Color(0.055, 0.13, 0.16, 1.0)` | Abyssal cryo-basalt basins and valley floors (`roughness -> 0.96`) |
| **`slope_color`** | `Color(0.30, 0.38, 0.40, 1.0)` | Fractured slate ridges and steep terrain flanks |
| **`highland_ice_color`** | `Color(0.78, 0.91, 0.95, 1.0)` | Sunlit glacial peaks and frost-dusted ridgelines (`roughness -> 0.72`) |

## 3. Atmosphere & Lighting Transitions ([PlanetaryEnvironment.gd](../../PlanetaryEnvironment.gd))

- **Sun (`DirectionalLight3D` `"SunLight"`):** `rotation_degrees = (-42, -28, 0)`, shadows enabled, `light_energy` interpolated `1.45` (thin upper atmosphere) to `1.15` (dense sea level).
- **Sky (`ProceduralSkyMaterial` + `FILMIC` tonemap + subtle glow `0.35`):** `sky_top_color = Color(0.08, 0.18, 0.34)`, `sky_horizon_color = Color(0.56, 0.72, 0.88)`, `ground_bottom_color = Color(0.025, 0.04, 0.06)`, `ground_horizon_color = Color(0.25, 0.34, 0.42)`.
- **Exponential Fog:** `FOG_BASE_DENSITY = 0.00012` scaled by `current_atmosphere_factor` (explicitly `0.0` / disabled above `atmosphere_ceiling`).

## 4. Vessel & Entity Visual Rig Contract ([EntityVisualsBuilder.gd](../../EntityVisualsBuilder.gd))

- **Player Vessel Root (`"ShipVisualRoot"`):** Procedurally built with **exactly `10` child nodes** (`test_adversarial_phaseD_challenger2.gd:402` invariant), including twin engine thruster plumes cached via `set_meta(&"plume_left", ...)` and `set_meta(&"plume_right", ...)` (`ADR-0005`).
- **Bank / Roll Animation:** Driven in ship-local frame via inverse-basis transformation of `angular_velocity` and `torque_input`.
- **Pooled Entities:** Projectile tracers (`128`-slot `ProjectilePoolManager`), hostile drones (`64`-slot `TargetPoolManager`), and decaying impact bursts (`32`-slot `ImpactEffectPoolManager`) strictly reuse pre-allocated mesh/material instances with zero runtime allocations.

## 5. HUD & Touch Semantic Color Hierarchy ([CockpitHUD.gd](../../CockpitHUD.gd), [MobileTouchLayout.gd](../../MobileTouchLayout.gd))

| Token | Value | Semantic Usage |
| :--- | :--- | :--- |
| **HUD Backing** | `Color(0.015, 0.05, 0.065, 0.82)` | Left telemetry box (`<= 310 px` wide) & right mission box (`180 px` wide) |
| **Nominal Telemetry** | `Color(0.2, 0.95, 0.86, 0.9)` | Altitude, speed, hull/fuel/gear gauges, guidance mode, boresight, waypoints |
| **Orbital Trajectory** | `Color(0.38, 0.88, 1.0, 0.92)` | Predicted 64-step Keplerian trajectory, radar alt, battery, lead reticle |
| **Caution / Heat / Fire** | `Color(1.0, 0.48, 0.22, 0.95)` | V/S, G-load, overheat lockout, caution banners, target lock, FIRE touch zone |
| **Critical Pull-Up / Occluded** | `Color(1.0, 0.25, 0.25, 1.0)` | GPWS `PULL UP - TERRAIN` alert box and occluded LOS reticle slash |
| **Touch Idle / Active** | `alpha 0.35` / `alpha 0.85` | Resting vs active thumb sticks (`STICK_MARGIN = 130.0`) & strips (`76.0 px`) |

## 6. Mobile Geometry & Draw-Call Budgets

- **Terrain Chunk Pool:** `256` pre-allocated `MeshInstance3D` slots (`VISUAL_POOL_SIZE = 256`), `34x34` skirted vertices (`2,178` triangles per active chunk leaf), `64` collider slots (`ColliderPoolManager.POOL_SIZE = 64`).
- **On-Device Vulkan Render Audit:** `NOT ASSESSED` (physical Adreno 840 GPU draw call and overdraw capture deferred to device test pass).
