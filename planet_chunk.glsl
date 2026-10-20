#[compute]
#version 450

// =============================================================================
// planet_chunk.glsl -- Godot 4 / Vulkan cube-sphere terrain chunk generator
//
// Dispatch (5, 5, 1) groups of 8x8x1 -> 1600 invocations, 1156 are written.
// Output   PlanetVertex[1156] std430, 32 B/vertex = 36,992 B storage buffer.
// Push     48 B: three vec4 at byte offsets 0, 16, 32.
//
// chunk_origin_and_scale
//   .xy  chunk lower-left corner in cube-face coordinates, range [-1, 1]
//   .z   chunk edge length in face coordinates (2.0 / 2^lod)
//   .w   chunk edge length in metres (skirt depth = 5% of this)
// cube_face_normal
//   .xyz unit cube-face normal, exactly one component is +/-1
//   .w   LOD level, reserved for CPU-side bookkeeping
// planet_radius_and_seed
//   .x   planet radius in metres
//   .y   noise seed, integral (exact while |seed| < 2^24)
//   .z   base noise frequency, lattice cells per unit sphere
//   .w   terrain displacement amplitude in metres
//
// Output layout, row-major, index = y * 34 + x:
//   position_uvx.xyz = chunk-local metres, origin at the sea-level point of the
//                      chunk's lower-left corner; .w = u in [0, 1]
//   normal_uvy.xyz   = unit surface normal in planet-local orientation;
//                      .w = v in [0, 1]
//
// Grid: 32x32 interior vertices (rings 1..32) plus a one-vertex skirt ring on
// every side (rings 0 and 33), 34x34 total. Skirt vertices repeat the boundary
// UV, so they inherit the boundary height, then move toward the planet centre
// by chunk_size * 0.05. Normals are left unmodified so the skirt shades as a
// continuation of the surface instead of a visible wall.
//
// The CPU must reconstruct the same frame and warp:
//   up = abs(n.y) < 0.99 ? vec3(0, 1, 0) : vec3(1, 0, 0)
//   t  = normalize(cross(up, n)); b = cross(n, t)
//   w  = tan(uv * PI / 4)
//   dir(uv) = normalize(n + w.x * t + w.y * b)
//   origin  = dir(chunk_origin.xy) * planet_radius
//
// All std430 members are vec4; never introduce a vec3 there (Adreno stride
// corruption).
//
// Precision: positions are emitted chunk-local, so float32 keeps ~0.06 m at a
// 1,000 km chunk extent. Subtracting the two radius-sized vectors costs about
// 0.2 m at a 2000 km radius, which is ~1e-5 of the LOD 0 vertex spacing and
// therefore below the visible threshold. The CPU is expected to hold the true
// double-precision world origin and add it after the GPU readback.
// =============================================================================

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform Params {
    vec4 chunk_origin_and_scale;
    vec4 cube_face_normal;
    vec4 planet_radius_and_seed;
} pc;

struct PlanetVertex {
    vec4 position_uvx;
    vec4 normal_uvy;
};

layout(set = 0, binding = 0, std430) restrict writeonly buffer VertexBuffer {
    PlanetVertex vertices[];
};

const uint GRID = 34u;
const uint INTERIOR = 32u;
const float QUARTER_PI = 0.7853981633974483;
const float SKIRT_FRACTION = 0.05;

// Integer lattice hash with a full avalanche finaliser.
uint hash3(ivec3 p, uint seed) {
    uint h = seed ^ 0x9e3779b9u;
    h ^= uint(p.x) * 0x8da6b343u; h = (h << 13) | (h >> 19);
    h ^= uint(p.y) * 0xd8163841u; h = (h << 17) | (h >> 15);
    h ^= uint(p.z) * 0xcb1ab31fu;
    h ^= h >> 16; h *= 0x7feb352du;
    h ^= h >> 15; h *= 0x846ca68bu;
    h ^= h >> 16;
    return h;
}

// One of the 12 edge gradients: all permutations of (+/-1, +/-1, 0).
vec3 grad12(uint h) {
    uint i = h % 12u;
    uint s = i & 3u;
    vec3 g = vec3(
        (s & 1u) == 0u ? 1.0 : -1.0,
        (s & 2u) == 0u ? 1.0 : -1.0,
        1.0);
    uint axis = i >> 2;
    if (axis == 0u) return vec3(0.0, g.x, g.y);
    if (axis == 1u) return vec3(g.x, 0.0, g.y);
    return vec3(g.x, g.y, 0.0);
}

// Accumulate value and analytic gradient for one simplex corner.
void add_corner(vec3 xc, ivec3 cell, uint seed, inout float value, inout vec3 deriv) {
    float t = 0.6 - dot(xc, xc);
    if (t <= 0.0) return;
    float t2 = t * t;
    float t4 = t2 * t2;
    vec3 g = grad12(hash3(cell, seed));
    float m = dot(g, xc);
    value += t4 * m;
    deriv += t4 * g - 8.0 * t2 * t * m * xc;
}

// 3D simplex noise: returns (value, d/dx, d/dy, d/dz), roughly [-1, 1].
vec4 snoise(vec3 v, uint seed) {
    const float F3 = 1.0 / 3.0;
    const float G3 = 1.0 / 6.0;

    float s = (v.x + v.y + v.z) * F3;
    ivec3 i = ivec3(floor(v + s));
    float skew = float(i.x + i.y + i.z) * G3;
    vec3 x0 = v - (vec3(i) - skew);

    ivec3 i1, i2;
    if (x0.x >= x0.y) {
        if (x0.y >= x0.z)      { i1 = ivec3(1, 0, 0); i2 = ivec3(1, 1, 0); }
        else if (x0.x >= x0.z) { i1 = ivec3(1, 0, 0); i2 = ivec3(1, 0, 1); }
        else                   { i1 = ivec3(0, 0, 1); i2 = ivec3(1, 0, 1); }
    } else {
        if (x0.y < x0.z)       { i1 = ivec3(0, 0, 1); i2 = ivec3(0, 1, 1); }
        else if (x0.x < x0.z)  { i1 = ivec3(0, 1, 0); i2 = ivec3(0, 1, 1); }
        else                   { i1 = ivec3(0, 1, 0); i2 = ivec3(1, 1, 0); }
    }

    vec3 x1 = x0 - vec3(i1) + G3;
    vec3 x2 = x0 - vec3(i2) + 2.0 * G3;
    vec3 x3 = x0 - 1.0 + 3.0 * G3;

    float value = 0.0;
    vec3 deriv = vec3(0.0);
    add_corner(x0, i, seed, value, deriv);
    add_corner(x1, i + i1, seed, value, deriv);
    add_corner(x2, i + i2, seed, value, deriv);
    add_corner(x3, i + ivec3(1), seed, value, deriv);
    return vec4(32.0 * value, 32.0 * deriv);
}

// 4 octaves, amplitude 1.0 -> 0.125, derivative w.r.t. the input position.
vec4 fbm4(vec3 p, uint seed) {
    float value = 0.0;
    vec3 deriv = vec3(0.0);
    float amp = 1.0;
    float freq = 1.0;
    float norm = 0.0;
    for (int o = 0; o < 4; ++o) {
        vec4 n = snoise(p * freq, seed + uint(o) * 0x9e3779b9u);
        value += amp * n.x;
        deriv += amp * freq * n.yzw;
        norm += amp;
        amp *= 0.5;
        freq *= 2.0;
    }
    return vec4(value, deriv) / norm;
}

// Cube face -> unit sphere with tangential warp to equalise corner density.
vec3 face_dir(vec2 uv, vec3 n, vec3 t, vec3 b) {
    vec2 w = tan(uv * QUARTER_PI);
    return normalize(n + w.x * t + w.y * b);
}

void main() {
    uvec2 id = gl_GlobalInvocationID.xy;
    if (id.x >= GRID || id.y >= GRID) return;

    vec3 n = pc.cube_face_normal.xyz;
    vec3 up = abs(n.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 t = normalize(cross(up, n));
    vec3 b = cross(n, t);

    // Ring 0 and ring 33 clamp onto the boundary UV: 32x32 interior + skirt.
    vec2 inner = clamp(vec2(id) - 1.0, vec2(0.0), vec2(float(INTERIOR - 1u)))
               / float(INTERIOR - 1u);
    vec2 uv = pc.chunk_origin_and_scale.xy + inner * pc.chunk_origin_and_scale.z;
    vec3 dir = face_dir(uv, n, t, b);

    float radius = pc.planet_radius_and_seed.x;
    float freq = pc.planet_radius_and_seed.z;
    float amp = pc.planet_radius_and_seed.w;
    uint seed = uint(int(pc.planet_radius_and_seed.y));

    vec4 f = fbm4(dir * freq, seed);
    float height = amp * f.x;
    vec3 grad = amp * freq * f.yzw;
    grad -= dot(grad, dir) * dir;   // keep the gradient tangential

    // Surface normal of r * dir + height(dir) * dir. The radial term carries the
    // radius so the slope stays correct for small noise amplitudes.
    vec3 nrm = normalize(dir * (radius + height) - grad);

    vec3 pos = dir * (radius + height)
             - face_dir(pc.chunk_origin_and_scale.xy, n, t, b) * radius;

    if (id.x == 0u || id.y == 0u || id.x == GRID - 1u || id.y == GRID - 1u) {
        pos -= dir * (pc.chunk_origin_and_scale.w * SKIRT_FRACTION);
    }

    uint idx = id.y * GRID + id.x;
    vertices[idx].position_uvx = vec4(pos, inner.x);
    vertices[idx].normal_uvy = vec4(nrm, inner.y);
}
