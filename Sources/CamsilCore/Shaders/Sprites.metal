#include "ShaderCommon.h"

struct SpriteData {
    float4 frame;  // center x, center y, width, height (points, top-left origin)
    float4 extra;  // rotation, alpha, 0, 0
    float4 motion; // velocity x, velocity y (points per second), time (seconds), lift (0 on the glass, 1 in the air)
};

struct SpriteOut {
    float4 position [[position]];
    float2 uv;
    float alpha;
};

inline float2 rotate2(float2 v, float angle) {
    float c = cos(angle), s = sin(angle);
    return float2(v.x * c - v.y * s, v.x * s + v.y * c);
}

inline float4 toClip(float2 p, float2 viewSize) {
    return float4(p.x / viewSize.x * 2.0 - 1.0, 1.0 - p.y / viewSize.y * 2.0, 0.0, 1.0);
}

vertex SpriteOut spriteVertex(uint vid [[vertex_id]],
                              constant SpriteData& s [[buffer(0)]],
                              constant float2& viewSize [[buffer(1)]]) {
    const float2 corners[4] = { float2(-0.5, -0.5), float2(0.5, -0.5), float2(-0.5, 0.5), float2(0.5, 0.5) };
    float2 p = s.frame.xy + rotate2(corners[vid] * s.frame.zw, s.extra.x);
    SpriteOut out;
    out.position = toClip(p, viewSize);
    out.uv = corners[vid] + 0.5;
    out.alpha = s.extra.y;
    return out;
}

fragment float4 spriteTextureFragment(SpriteOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 c = tex.sample(s, in.uv);
    return float4(c.rgb, c.a * in.alpha);
}

// MARK: - Cloth

constant uint kClothGrid = 24;

struct ClothOut {
    float4 position [[position]];
    float2 uv;
    float alpha;
    float2 drag;     // hand motion in the cloth frame, length 0...1
    float time;
    float lift;
    float rotation;
};

/// Hand motion in the cloth frame. Fast motion saturates to length 1.
inline float2 clothDrag(constant SpriteData& s) {
    float2 v = rotate2(s.motion.xy, -s.extra.x) / 1400.0;
    return v / (1.0 + length(v));
}

/// Bend of the cloth, in units of the sprite size. q is -0.5...0.5 from the center.
inline float2 clothBend(float2 q, float2 drag, float time, float lift) {
    float r = length(q);
    float speed = length(drag);
    float2 dir = speed > 1e-4 ? drag / speed : float2(1.0, 0.0);
    float2 perp = float2(-dir.y, dir.x);
    // The hand holds the center. The edges drag behind it.
    float2 off = -drag * (r * r) * 0.6;
    // The trailing edge flaps from side to side.
    float behind = saturate(-dot(q, dir) * 2.0);
    off += perp * sin(time * 14.0 + dot(q, dir) * 9.0) * speed * behind * 0.05;
    // The leading edge bunches up against the hand.
    float ahead = saturate(dot(q, dir) * 2.0);
    off -= dir * ahead * ahead * speed * 0.06;
    // Small movement of the hand at rest.
    off += float2(sin(time * 1.7 + q.y * 5.0), cos(time * 1.3 + q.x * 5.0)) * 0.005 * (0.5 + lift);
    // In the air the corners hang down a little.
    off.y += lift * r * r * 0.1;
    return off;
}

vertex ClothOut clothVertex(uint vid [[vertex_id]],
                            constant SpriteData& s [[buffer(0)]],
                            constant float2& viewSize [[buffer(1)]]) {
    const uint2 corners[6] = { uint2(0, 0), uint2(1, 0), uint2(0, 1), uint2(1, 0), uint2(1, 1), uint2(0, 1) };
    uint cell = vid / 6;
    uint2 g = uint2(cell % kClothGrid, cell / kClothGrid) + corners[vid % 6];
    float2 uv = float2(g) / float(kClothGrid);
    float2 q = uv - 0.5;
    float2 drag = clothDrag(s);
    float2 local = (q + clothBend(q, drag, s.motion.z, s.motion.w)) * s.frame.zw;
    ClothOut out;
    out.position = toClip(s.frame.xy + rotate2(local, s.extra.x), viewSize);
    out.uv = uv;
    out.alpha = s.extra.y;
    out.drag = drag;
    out.time = s.motion.z;
    out.lift = s.motion.w;
    out.rotation = s.extra.x;
    return out;
}

/// Signed distance to the cloth edge: a square with soft corners and a cut, slightly uneven edge.
inline float clothEdge(float2 uv) {
    float2 q = uv - 0.5;
    const float extent = 0.45, corner = 0.05;
    float2 b = abs(q) - (extent - corner);
    float d = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - corner;
    return d + (valueNoise(uv * 38.0, 5.0) - 0.5) * 0.006;
}

/// Height of the cloth surface: old fold lines plus wrinkles that the hand motion pushes up.
inline float clothHeight(float2 q, float2 drag, float time, float lift) {
    float speed = length(drag);
    float2 dir = speed > 1e-4 ? drag / speed : float2(1.0, 0.0);
    float2 perp = float2(-dir.y, dir.x);
    float h = (fbm(q * 3.0 + 7.0, 3.0) - 0.5) * 0.03;
    // Two fold lines from the package, like a cloth that came out of a stack.
    float foldA = q.x * 0.97 + q.y * 0.24 - 0.04;
    float foldB = q.y * 0.95 - q.x * 0.3 + 0.12;
    h += 0.008 * exp(-foldA * foldA / 0.0006) - 0.004 * exp(-foldB * foldB / 0.0004);
    // Wrinkles across the motion, mostly on the leading side.
    float ahead = smoothstep(-0.15, 0.4, dot(q, dir));
    float wave = dot(q, dir) * 52.0 + dot(q, perp) * 5.0 + fbm(q * 5.0, 9.0) * 5.0 - time * 3.0;
    h += speed * ahead * 0.012 * (0.5 + 0.5 * sin(wave));
    // In the air the corners curl up.
    h += lift * dot(q, q) * 0.05;
    return h;
}

fragment float4 clothFragment(ClothOut in [[stage_in]]) {
    float d = clothEdge(in.uv);
    float mask = 1.0 - smoothstep(-0.003, 0.002, d);
    if (mask <= 0.0) discard_fragment();

    float2 q = in.uv - 0.5;
    const float e = 0.004;
    float h = clothHeight(q, in.drag, in.time, in.lift);
    float hx = clothHeight(q + float2(e, 0.0), in.drag, in.time, in.lift);
    float hy = clothHeight(q + float2(0.0, e), in.drag, in.time, in.lift);
    float3 n = normalize(float3(-(hx - h) / e, -(hy - h) / e, 1.0));
    n.xy = rotate2(n.xy, in.rotation);   // light comes from the screen, not from the cloth

    float3 light = normalize(float3(-0.45, -0.6, 0.75));
    float diffuse = 0.74 + 0.4 * dot(n, light);
    float spec = pow(saturate(dot(reflect(-light, n), float3(0, 0, 1))), 12.0) * 0.06;

    // Nonwoven sponge cloth: fine pores, a soft mottle, no weave.
    float mottle = fbm(in.uv * 18.0, 3.0);
    float grain = valueNoise(in.uv * 210.0, 11.0);
    float pores = smoothstep(0.78, 0.9, valueNoise(in.uv * 330.0, 13.0));
    float3 base = float3(1.0, 0.9, 0.1);
    float3 color = base * (0.9 + 0.12 * mottle) * (0.95 + 0.07 * grain) * (1.0 - 0.18 * pores);
    // The cut edge is a little darker, and it shows the cloth thickness.
    color *= 1.0 - 0.18 * smoothstep(-0.012, 0.0, d);
    color = color * diffuse + spec;
    return float4(saturate(color), mask * in.alpha);
}

fragment float4 clothShadowFragment(ClothOut in [[stage_in]]) {
    float d = clothEdge(in.uv);
    float shadow = 1.0 - smoothstep(-0.05, 0.05, d);
    if (shadow <= 0.0) discard_fragment();
    return float4(0.0, 0.0, 0.0, shadow * (0.3 - 0.12 * in.lift) * in.alpha);
}

// MARK: - Spray mist

struct MistOut {
    float4 position [[position]];
    float2 local;
    float alpha;
};

vertex MistOut mistVertex(uint vid [[vertex_id]],
                          uint iid [[instance_id]],
                          constant float4* mist [[buffer(0)]],   // x, y, size, alpha
                          constant float2& viewSize [[buffer(1)]]) {
    const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float4 m = mist[iid];
    MistOut out;
    out.position = toClip(m.xy + corners[vid] * m.z * 0.5, viewSize);
    out.local = corners[vid];
    out.alpha = m.w;
    return out;
}

fragment float4 mistFragment(MistOut in [[stage_in]]) {
    float r2 = dot(in.local, in.local);
    if (r2 > 1.0) discard_fragment();
    return float4(0.94, 0.97, 1.0, exp(-r2 * 3.5) * in.alpha);
}
