#pragma once
#include <metal_stdlib>
using namespace metal;

inline float hash21(float2 p, float seed) {
    p = fract(p * float2(123.34, 456.21) + seed);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

inline float valueNoise(float2 p, float seed) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i, seed);
    float b = hash21(i + float2(1, 0), seed);
    float c = hash21(i + float2(0, 1), seed);
    float d = hash21(i + float2(1, 1), seed);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

inline float fbm(float2 p, float seed) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * valueNoise(p, seed + float(i) * 17.0);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}
