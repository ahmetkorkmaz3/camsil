#include "ShaderCommon.h"

struct FullscreenOut {
    float4 position [[position]];
    float2 uv;
};

vertex FullscreenOut fullscreenVertex(uint vid [[vertex_id]]) {
    float2 pos = float2((vid << 1) & 2, vid & 2);
    FullscreenOut out;
    out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
    out.uv = float2(pos.x, 1.0 - pos.y);
    return out;
}

struct CompositeUniforms {
    float4 state;  // dirt opacity, window opacity, sparkle (< 0 off), debug mode
    float4 optics; // refraction, 0, 0, 0
};

fragment float4 compositeFragment(FullscreenOut in [[stage_in]],
                                  texture2d<float> screen [[texture(0)]],
                                  texture2d<float> screenBlur [[texture(1)]],
                                  texture2d<float> dirtTex [[texture(2)]],
                                  texture2d<float> wetTex [[texture(3)]],
                                  texture2d<float> drops [[texture(4)]],
                                  constant CompositeUniforms& u [[buffer(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float2 uv = in.uv;
    float4 dn = drops.sample(s, uv);
    float thick = dn.b;
    float4 d = dirtTex.sample(s, uv) * u.state.x;
    float w = wetTex.sample(s, uv).r;

    int debugMode = int(u.state.w);
    if (debugMode == 1) return float4(d.rgb, 1.0);
    if (debugMode == 2) return float4(w, w, w, 1.0);
    if (debugMode == 3) return float4(dn.rg * 0.5 + 0.5, thick, 1.0);

    float2 ruv = uv - dn.rg * thick * u.optics.x;
    float haze = d.r * (1.0 - 0.4 * w);
    float blurAmount = saturate(haze * 0.9 + d.b * 0.6);
    float maxLevel = float(screenBlur.get_num_mip_levels() - 1);
    float lod = blurAmount * min(maxLevel, 5.0);

    float3 clear = screen.sample(s, ruv).rgb;
    float3 blurred = screenBlur.sample(s, ruv, level(lod)).rgb;
    float3 color = mix(clear, blurred, saturate(blurAmount * 1.5));
    color = mix(color, float3(0.78, 0.76, 0.72), haze * 0.45);   // dust film
    color = mix(color, float3(0.92, 0.92, 0.90), d.g * 0.55);    // lime spots
    color = mix(color, color * 0.85 + 0.12, d.b * 0.5);          // greasy prints

    if (thick > 0.01) {
        float3 n = normalize(float3(dn.rg, max(thick, 0.05)));
        float3 light = normalize(float3(-0.5, -0.6, 0.65));       // from the top left
        float spec = pow(saturate(dot(n, light)), 40.0);
        color *= 0.8 + 0.2 * thick;
        color += spec * 0.9;
    }

    if (u.state.z >= 0.0) {
        float band = u.state.z * 2.4 - 0.7;
        float x = (uv.x + uv.y) * 0.5;
        float dx = x - band;
        color += exp(-dx * dx / 0.003) * 0.7;
    }

    float a = u.state.y;
    return float4(saturate(color) * a, a);
}
