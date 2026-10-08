import Metal
import XCTest
@testable import CamsilCore

enum TestGPU {
    static let context: MetalContext = {
        do { return try MetalContext() } catch { fatalError("Metal is not available: \(error)") }
    }()

    static func run(_ body: (MTLCommandBuffer) -> Void) {
        let cb = context.queue.makeCommandBuffer()!
        body(cb)
        cb.commit()
        cb.waitUntilCompleted()
    }

    static func readRGBA16(_ t: MTLTexture) -> [SIMD4<Float>] {
        var raw = [Float16](repeating: 0, count: t.width * t.height * 4)
        raw.withUnsafeMutableBytes {
            t.getBytes($0.baseAddress!, bytesPerRow: t.width * 8,
                       from: MTLRegionMake2D(0, 0, t.width, t.height), mipmapLevel: 0)
        }
        return stride(from: 0, to: raw.count, by: 4).map { (i: Int) -> SIMD4<Float> in
            SIMD4<Float>(Float(raw[i]), Float(raw[i + 1]), Float(raw[i + 2]), Float(raw[i + 3]))
        }
    }

    static func readR16(_ t: MTLTexture) -> [Float] {
        var raw = [Float16](repeating: 0, count: t.width * t.height)
        raw.withUnsafeMutableBytes {
            t.getBytes($0.baseAddress!, bytesPerRow: t.width * 2,
                       from: MTLRegionMake2D(0, 0, t.width, t.height), mipmapLevel: 0)
        }
        return raw.map { Float($0) }
    }

    static func fillRGBA16(_ t: MTLTexture, _ v: SIMD4<Float>) {
        let px = [Float16(v.x), Float16(v.y), Float16(v.z), Float16(v.w)]
        let raw = [Float16]((0..<(t.width * t.height)).flatMap { _ in px })
        raw.withUnsafeBytes {
            t.replace(region: MTLRegionMake2D(0, 0, t.width, t.height), mipmapLevel: 0,
                      withBytes: $0.baseAddress!, bytesPerRow: t.width * 8)
        }
    }

    static func fillR16(_ t: MTLTexture, _ v: Float) {
        let raw = [Float16](repeating: Float16(v), count: t.width * t.height)
        raw.withUnsafeBytes {
            t.replace(region: MTLRegionMake2D(0, 0, t.width, t.height), mipmapLevel: 0,
                      withBytes: $0.baseAddress!, bytesPerRow: t.width * 2)
        }
    }

    /// Shared BGRA8 texture. `pixel` returns RGBA in 0...255.
    static func makeBGRA(width: Int, height: Int, usage: MTLTextureUsage = [.shaderRead],
                         pixel: (Int, Int) -> SIMD4<UInt8> = { _, _ in .zero }) -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        d.usage = usage
        d.storageMode = .shared
        let t = context.device.makeTexture(descriptor: d)!
        var raw = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let c = pixel(x, y)
                let i = (y * width + x) * 4
                raw[i] = c.z; raw[i + 1] = c.y; raw[i + 2] = c.x; raw[i + 3] = c.w
            }
        }
        t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: raw, bytesPerRow: width * 4)
        return t
    }

    /// Returns RGBA in 0...255.
    static func readBGRA(_ t: MTLTexture) -> [SIMD4<UInt8>] {
        var raw = [UInt8](repeating: 0, count: t.width * t.height * 4)
        t.getBytes(&raw, bytesPerRow: t.width * 4, from: MTLRegionMake2D(0, 0, t.width, t.height), mipmapLevel: 0)
        return stride(from: 0, to: raw.count, by: 4).map { SIMD4(raw[$0 + 2], raw[$0 + 1], raw[$0], raw[$0 + 3]) }
    }
}
