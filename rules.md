# Project Architecture & AI Guardrails: Procedural Space Game (Android / SD 8 Elite Gen 5)

## 1. Hardware Target Constraints
- SoC: Snapdragon 8 Elite Gen 5 (2x 4.74GHz Oryon Prime, 6x 3.63GHz Oryon Perf, Adreno 840 GPU, 12GB LPDDR5X RAM).
- Graphics API: Vulkan 1.4 Mobile Renderer.
- Memory Rule: ZERO runtime allocation in `_process` or `_physics_process`. All terrain chunks, collider meshes, and projectiles MUST be pre-allocated in fixed-size Ring Buffers at startup.
- Threading Rule: Max 4 background worker threads for Quadtree evaluation and physics collider baking.

## 2. Mathematical & Shader Contracts (STRICT)
- NEVER use `vec3` inside Vulkan `std430` storage buffers (`buffer` blocks). Always use `vec4` (16-byte aligned) to prevent Adreno GPU stride corruption.
- Planet Surface Projection: Use Cube-Sphere with tangential warp (`tan(uv * PI / 4.0)`) before normalizing to eliminate corner grid stretching.
- Precision: All world positions on CPU must use 64-bit floats (`double` / Godot 64-bit physics or manual `Vector3i` sector + `Vector3` local offset). Rebase origin when camera exceeds 2,000m from `(0,0,0)`.
- Chunk LOD Seams: Do NOT write complex topological index stitching. Generate a 32x32 grid per chunk with a 1-vertex perimeter skirt extruded toward planet center by `chunk_size * 0.05`.

## 3. Code Decomposition Rule for Agents
- Never generate scripts longer than 250 lines.
- Separate math logic (pure static functions with headless unit tests) from engine scene nodes.