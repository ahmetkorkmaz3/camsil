#include "ShaderCommon.h"

struct DirtParams {
    float4 size;   // width, height, seed, spot count
    float4 counts; // print count, 0, 0, 0
};

kernel void generateDirt(texture2d<half, access::write> dirt [[texture(0)]],
                         constant DirtParams& p [[buffer(0)]],
                         constant float4* spots [[buffer(1)]],    // x, y, radius, strength
                         constant float4* prints [[buffer(2)]],   // x, y, radius, angle
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dirt.get_width() || gid.y >= dirt.get_height()) return;
    float2 pos = float2(gid) + 0.5;
    float seed = p.size.z;

    float dust = 0.55 + 0.35 * fbm(pos / 180.0, seed) + 0.1 * valueNoise(pos / 3.0, seed + 3.0);
    dust = saturate(dust);

    float spotValue = 0.0;
    int spotCount = int(p.size.w);
    for (int i = 0; i < spotCount; i++) {
        float4 s = spots[i];
        float d = distance(pos, s.xy) / s.z;
        if (d < 1.2) {
            float rim = smoothstep(0.75, 0.95, d) * (1.0 - smoothstep(0.95, 1.1, d));
            float fill = (1.0 - smoothstep(0.0, 1.0, d)) * 0.35;
            spotValue = max(spotValue, (rim + fill) * s.w);
        }
    }

    float printValue = 0.0;
    int printCount = int(p.counts.x);
    for (int i = 0; i < printCount; i++) {
        float4 f = prints[i];
        float2 q = pos - f.xy;
        float c = cos(f.w), s = sin(f.w);
        q = float2(c * q.x + s * q.y, -s * q.x + c * q.y);
        q.y /= 0.7;
        float r = length(q) / f.z;
        if (r < 1.1) {
            float ridges = 0.5 + 0.5 * sin(r * f.z * 0.9 + valueNoise(q / 6.0, seed) * 3.0);
            float mask = 1.0 - smoothstep(0.7, 1.05, r);
            printValue = max(printValue, ridges * mask * 0.8);
        }
    }

    dirt.write(half4(half(dust), half(saturate(spotValue)), half(saturate(printValue)), 1.0h), gid);
}

kernel void sumDirtRows(texture2d<half, access::read> dirt [[texture(0)]],
                        device float* rowSums [[buffer(0)]],
                        uint gid [[thread_position_in_grid]]) {
    if (gid >= dirt.get_height()) return;
    float sum = 0.0;
    for (uint x = 0; x < dirt.get_width(); x++) {
        half4 d = dirt.read(uint2(x, gid));
        sum += float(max(d.r, max(d.g, d.b)));
    }
    rowSums[gid] = sum;
}
