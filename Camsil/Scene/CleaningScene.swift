import CamsilCore
import MetalKit

/// First version: dirty glass over the live screen. Task 12 adds the tools.
final class CleaningScene: NSObject, MTKViewDelegate {
    var onQuit: (() -> Void)?

    private let context: MetalContext
    private let capture: ScreenCapture
    private let textures: SimulationTextures
    private let compositor: Compositor
    private let dropRenderer: DropletRenderer
    private let session: SessionController
    private var lastInputTime: Double
    private var debugMode = 0
    private var didQuit = false

    init(context: MetalContext, capture: ScreenCapture, viewSizePoints: SIMD2<Float>,
         backingScale: Float, pixelFormat: MTLPixelFormat) throws {
        // Locals first: an NSObject subclass cannot read self before super.init.
        let space = SimSpace(viewSizePoints: viewSizePoints, backingScale: backingScale)
        let textures = try SimulationTextures(device: context.device, size: space.simSize)
        let dropRenderer = try DropletRenderer(context: context)
        let generator = try DirtGenerator(context: context)
        guard let cb = context.queue.makeCommandBuffer() else { throw MetalError.noDevice }
        generator.encode(into: textures.dirt, seed: UInt64.random(in: 1...UInt64.max), commandBuffer: cb)
        dropRenderer.encode([], into: textures.dropNormals, commandBuffer: cb)
        cb.commit()
        cb.waitUntilCompleted()

        self.context = context
        self.capture = capture
        self.textures = textures
        self.dropRenderer = dropRenderer
        compositor = try Compositor(context: context, pixelFormat: pixelFormat)
        let now = CACurrentMediaTime()
        session = SessionController(startTime: now)
        lastInputTime = now
        super.init()
    }

    func handle(_ input: ToolInput) {
        lastInputTime = CACurrentMediaTime()
    }

    func toggleDebug() {
        debugMode = (debugMode + 1) % 4
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        session.update(time: now, cleanFraction: 0, lastInputTime: lastInputTime)
        guard let cb = context.queue.makeCommandBuffer() else { return }
        if let screen = capture.latestTexture,
           let blur = compositor.prepareBlur(screen: screen, commandBuffer: cb),
           let rpd = view.currentRenderPassDescriptor,
           let drawable = view.currentDrawable,
           let encoder = cb.makeRenderCommandEncoder(descriptor: rpd) {
            let uniforms = CompositeUniforms(dirtOpacity: session.dirtOpacity, windowOpacity: session.windowOpacity,
                                             sparkle: session.sparkle, debugMode: debugMode)
            compositor.encode(encoder: encoder, screen: screen, blur: blur, textures: textures, uniforms: uniforms)
            encoder.endEncoding()
            cb.present(drawable)
        }
        cb.commit()
        if session.shouldQuit && !didQuit {
            didQuit = true
            onQuit?()
        }
    }
}
