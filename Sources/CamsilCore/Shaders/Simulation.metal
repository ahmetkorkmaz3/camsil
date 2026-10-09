#include "ShaderCommon.h"

kernel void addWetness(texture2d<half, access::read_write> wet [[texture(0)]],
                       constant float4* circles [[buffer(0)]],   // x, y, radius, amount
                       constant uint& count [[buffer(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= wet.get_width() || gid.y >= wet.get_height()) return;
    float2 pos = float2(gid) + 0.5;
    float w = float(wet.read(gid).r);
    for (uint i = 0; i < count; i++) {
        float4 c = circles[i];
        float d = distance(pos, c.xy) / c.z;
        if (d < 1.0) {
            w = min(1.0, w + c.w * (1.0 - d * d));
        }
    }
    wet.write(half4(half(w)), gid);
}

kernel void dryWetness(texture2d<half, access::read_write> wet [[texture(0)]],
                       constant float& amount [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= wet.get_width() || gid.y >= wet.get_height()) return;
    float w = float(wet.read(gid).r);
    wet.write(half4(half(max(0.0, w - amount))), gid);
}

struct WipeParams {
    float4 segment; // from.xy, to.xy
    float4 info;    // radius, origin.x, origin.y, wet threshold
    float4 rates;   // wet dust, wet spots, wet prints, dry dust
    float4 extra;   // smear distance (fraction of radius), smear rate, pickup rate, stripe frequency
};

// GPU version of WipeRules.wipe. Keep both in sync.
kernel void wipe(texture2d<half, access::read> dirtIn [[texture(0)]],
                 texture2d<half, access::write> dirtOut [[texture(1)]],
                 texture2d<half, access::read_write> wet [[texture(2)]],
                 constant WipeParams& p [[buffer(0)]],
                 uint2 tid [[thread_position_in_grid]]) {
    uint2 gid = tid + uint2(p.info.yz);
    if (gid.x >= dirtOut.get_width() || gid.y >= dirtOut.get_height()) return;
    float2 pos = float2(gid) + 0.5;
    float2 a = p.segment.xy;
    float2 b = p.segment.zw;
    float2 ab = b - a;
    float len2 = max(dot(ab, ab), 1e-4);
    float t = saturate(dot(pos - a, ab) / len2);
    float dist = distance(pos, a + ab * t);
    float radius = p.info.x;
    float4 d = float4(dirtIn.read(gid));
    if (dist >= radius) {
        dirtOut.write(half4(d), gid);
        return;
    }
    float s = 1.0 - smoothstep(radius * 0.6, radius, dist);
    float w = float(wet.read(gid).r);
    float2 dir = ab / sqrt(len2);
    float3 dirt = d.rgb;
    if (w > p.info.w) {
        dirt.r *= 1.0 - p.rates.x * s;
        dirt.g *= 1.0 - p.rates.y * s;
        dirt.b *= 1.0 - p.rates.z * s;
    } else {
        // Dry cloth pulls dirt from behind it and leaves streaks.
        int2 src = int2(pos - dir * radius * p.extra.x);
        src = clamp(src, int2(0), int2(int(dirtIn.get_width()) - 1, int(dirtIn.get_height()) - 1));
        float3 behind = float3(dirtIn.read(uint2(src)).rgb);
        dirt.r = mix(dirt.r, behind.r, p.extra.y * s);
        dirt.b = max(dirt.b, mix(dirt.b, behind.b, p.extra.y * s));
        float2 perp = float2(-dir.y, dir.x);
        float stripe = 0.5 + 0.5 * sin(dot(pos, perp) * p.extra.w);
        dirt.r *= 1.0 - p.rates.w * s * 2.0 * stripe;
    }
    dirtOut.write(half4(half3(dirt), 1.0h), gid);
    wet.write(half4(half(w * (1.0 - p.extra.z * s))), gid);
}
