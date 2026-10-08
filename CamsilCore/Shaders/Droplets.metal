#include "ShaderCommon.h"

struct DropOut {
    float4 position [[position]];
    float2 local;
};

vertex DropOut dropVertex(uint vid [[vertex_id]],
                          uint iid [[instance_id]],
                          constant float4* drops [[buffer(0)]],   // x, y, radius, 0
                          constant float2& size [[buffer(1)]]) {
    const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    float2 c = corners[vid];
    float4 d = drops[iid];
    float2 p = d.xy + c * d.z;
    DropOut out;
    out.position = float4(p.x / size.x * 2.0 - 1.0, 1.0 - p.y / size.y * 2.0, 0.0, 1.0);
    out.local = c;
    return out;
}

// RG: normal (x right, y down), B: thickness.
fragment float4 dropFragment(DropOut in [[stage_in]]) {
    float r2 = dot(in.local, in.local);
    if (r2 > 1.0) discard_fragment();
    float h = sqrt(1.0 - r2);
    return float4(in.local, h, 1.0);
}
