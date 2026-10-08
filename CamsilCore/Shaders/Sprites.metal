#include "ShaderCommon.h"

struct SpriteData {
    float4 frame; // center x, center y, width, height (points, top-left origin)
    float4 extra; // rotation, alpha, 0, 0
};

struct SpriteOut {
    float4 position [[position]];
    float2 uv;
    float alpha;
};

vertex SpriteOut spriteVertex(uint vid [[vertex_id]],
                              constant SpriteData& s [[buffer(0)]],
                              constant float2& viewSize [[buffer(1)]]) {
    const float2 corners[4] = { float2(-0.5, -0.5), float2(0.5, -0.5), float2(-0.5, 0.5), float2(0.5, 0.5) };
    float2 c = corners[vid] * s.frame.zw;
    float cr = cos(s.extra.x), sr = sin(s.extra.x);
    float2 p = s.frame.xy + float2(c.x * cr - c.y * sr, c.x * sr + c.y * cr);
    SpriteOut out;
    out.position = float4(p.x / viewSize.x * 2.0 - 1.0, 1.0 - p.y / viewSize.y * 2.0, 0.0, 1.0);
    out.uv = corners[vid] + 0.5;
    out.alpha = s.extra.y;
    return out;
}

fragment float4 spriteTextureFragment(SpriteOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float4 c = tex.sample(s, in.uv);
    return float4(c.rgb, c.a * in.alpha);
}

// A green microfiber cloth, drawn with noise. No image file.
fragment float4 clothFragment(SpriteOut in [[stage_in]]) {
    float2 p = in.uv * 2.0 - 1.0;
    float edge = length(p * float2(1.0, 1.15)) + (valueNoise(in.uv * 6.0, 2.0) - 0.5) * 0.25;
    float mask = 1.0 - smoothstep(0.85, 0.95, edge);
    if (mask <= 0.0) discard_fragment();
    float fibers = fbm(in.uv * 60.0, 7.0);
    float folds = 0.5 + 0.5 * sin((p.x + p.y * 0.4) * 9.0 + fbm(in.uv * 4.0, 1.0) * 4.0);
    float3 base = float3(0.55, 0.82, 0.55);
    float3 color = base * (0.75 + 0.25 * fibers) * (0.85 + 0.15 * folds);
    return float4(color, mask * in.alpha);
}
