import Metal

public enum MetalError: Error, Equatable {
    case noDevice
    case missingFunction(String)
    case textureCreation
    case bufferCreation
    case missingShaders
}

public final class MetalContext {
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let library: MTLLibrary

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw MetalError.noDevice
        }
        self.device = device
        self.queue = queue
        library = try device.makeLibrary(source: Self.shaderSource(), options: nil)
    }

    /// SwiftPM copies the .metal files as resources but does not compile them, so the library is
    /// compiled here. The source is the shared header followed by each .metal file without its include line.
    static func shaderSource() throws -> String {
        guard let dir = shaderBundle().url(forResource: "Shaders", withExtension: nil) else {
            throw MetalError.missingShaders
        }
        let include = "#include \"ShaderCommon.h\""
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "metal" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else { throw MetalError.missingShaders }
        var parts = [try String(contentsOf: dir.appendingPathComponent("ShaderCommon.h"), encoding: .utf8)]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            parts.append(text.replacingOccurrences(of: include, with: "// \(file.lastPathComponent)"))
        }
        return parts.joined(separator: "\n")
    }

    /// In the app, scripts/bundle.sh puts the resource bundle in Contents/Resources, because codesign rejects
    /// files in the root of an app. Bundle.module looks only in the app root and in the .build folder.
    private static func shaderBundle() -> Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Camsil_CamsilCore.bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }

    public func function(_ name: String) throws -> MTLFunction {
        guard let f = library.makeFunction(name: name) else { throw MetalError.missingFunction(name) }
        return f
    }

    public func computePipeline(_ name: String) throws -> MTLComputePipelineState {
        try device.makeComputePipelineState(function: function(name))
    }

    public func dispatch2D(_ encoder: MTLComputeCommandEncoder, width: Int, height: Int) {
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
    }
}
