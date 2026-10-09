import CamsilCore
import MetalKit
import simd

/// One frame: input → simulation → droplets → composite → tool sprite → HUD.
final class CleaningScene: NSObject, MTKViewDelegate {
    var onQuit: (() -> Void)?
    /// Called once, on the main thread, when the first screen frame is drawn.
    var onFirstFrame: (() -> Void)?

    private let context: MetalContext
    private let capture: ScreenCapture
    private let sound: SoundPlayer
    private let hud: HUD
    private let bottle: MTLTexture
    private let space: SimSpace
    private let textures: SimulationTextures
    private let simulation: SimulationGPU
    private let dropRenderer: DropletRenderer
    private let compositor: Compositor
    private let sprites: SpriteRenderer
    private let progressCounter: ProgressCounter
    private let tools = ToolController()
    private let droplets: DropletSystem
    private let mist = MistSystem()
    /// Nil until the first screen frame. The session clock starts there.
    private var session: SessionController?
    private let cleanProgress: CleanProgress
    private var rng: SeededRandom
    private var pending: [ToolAction] = []
    private var cleanFraction: Float = 0
    private var lastFrameTime: Double
    private var lastInputTime: Double
    private var lastProgressTime: Double = 0
    private var lastSprayTime: Double = -10
    private let startTime: Double
    private var clothAngle: Float = 0
    private var clothVelocity: SIMD2<Float> = .zero
    private var clothLift: Float = 1
    private var lastCursor: SIMD2<Float>?
    /// The hand that holds the bottle. It follows the cursor on a spring.
    private var handPosition: SIMD2<Float>?
    private var handVelocity: SIMD2<Float> = .zero
    private var wipeSpeed: Float = 0
    private var previousPhase: SessionPhase = .intro
    private var debugMode = 0
    private var didQuit = false

    init(context: MetalContext, capture: ScreenCapture, sound: SoundPlayer, hud: HUD, bottle: MTLTexture,
         viewSizePoints: SIMD2<Float>, backingScale: Float, pixelFormat: MTLPixelFormat) throws {
        // Locals first: an NSObject subclass cannot read self before super.init.
        let seed = UInt64.random(in: 1...UInt64.max)
        let space = SimSpace(viewSizePoints: viewSizePoints, backingScale: backingScale)
        let textures = try SimulationTextures(device: context.device, size: space.simSize)
        let dropRenderer = try DropletRenderer(context: context)
        let progressCounter = try ProgressCounter(context: context)
        let generator = try DirtGenerator(context: context)
        guard let cb = context.queue.makeCommandBuffer() else { throw MetalError.noDevice }
        generator.encode(into: textures.dirt, seed: seed, commandBuffer: cb)
        dropRenderer.encode([], into: textures.dropNormals, commandBuffer: cb)
        cb.commit()
        cb.waitUntilCompleted()

        self.context = context
        self.capture = capture
        self.sound = sound
        self.hud = hud
        self.bottle = bottle
        self.space = space
        self.textures = textures
        self.dropRenderer = dropRenderer
        self.progressCounter = progressCounter
        rng = SeededRandom(seed: seed)
        simulation = try SimulationGPU(context: context, textures: textures)
        compositor = try Compositor(context: context, pixelFormat: pixelFormat)
        sprites = try SpriteRenderer(context: context, pixelFormat: pixelFormat)
        droplets = DropletSystem(bounds: SIMD2(Float(space.simSize.x), Float(space.simSize.y)))
        guard let initialDirt = progressCounter.measureNow(dirt: textures.dirt) else {
            throw MetalError.bufferCreation
        }
        cleanProgress = CleanProgress(initialDirt: initialDirt)

        let now = CACurrentMediaTime()
        lastFrameTime = now
        lastInputTime = now
        startTime = now
        super.init()
    }

    private var isActive: Bool {
        guard let phase = session?.phase else { return false }
        return phase == .intro || phase == .cleaning
    }

    func handle(_ input: ToolInput) {
        let now = CACurrentMediaTime()
        lastInputTime = now
        guard isActive else { return }
        pending += tools.handle(input, time: now)
    }

    func toggleDebug() {
        debugMode = (debugMode + 1) % 4
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        // Before the first frame, present nothing and keep the clock stopped.
        guard capture.latestTexture != nil else { return }
        if session == nil { beginSession(now: now) }
        guard let session else { return }
        let dt = Float(min(now - lastFrameTime, 0.05))
        lastFrameTime = now
        guard let cb = context.queue.makeCommandBuffer() else { return }

        var actions = pending
        pending.removeAll()
        if isActive { actions += tools.tick(time: now) }
        updateHand(dt: dt)

        var wetCircles: [SIMD4<Float>] = []
        var wiped: Float = 0
        for action in actions {
            switch action {
            case .spray(let p):
                // The water reaches the glass when the mist lands, a little after the trigger.
                mist.spray(from: bottlePose(now: now).nozzle, to: p, radius: Tuning.sprayRadiusPoints, rng: &rng)
                sound.playSpray()
                lastSprayTime = now
            case .wipe(let a, let b):
                let r = space.lengthToSim(Tuning.clothRadiusPoints)
                simulation.encodeWipe(from: space.toSim(a), to: space.toSim(b), radius: r, commandBuffer: cb)
                droplets.wipe(from: space.toSim(a), to: space.toSim(b), radius: r)
                let d = b - a
                wiped += simd_length(d)
            case .toolChanged:
                break
            }
        }
        wipeSpeed = wipeSpeed * 0.8 + (wiped / max(dt, 0.001)) * 0.2
        sound.setSqueak(speed: isActive && tools.tool == .cloth && tools.isPressed ? wipeSpeed : 0)

        let landing = mist.step(dt: dt)
        droplets.land(landing.drops.map {
            Droplet(position: space.toSim(SIMD2($0.x, $0.y)), radius: $0.z, velocity: 0)
        })
        for p in landing.impacts {
            let c = space.toSim(p)
            wetCircles.append(SIMD4(c.x, c.y, space.lengthToSim(Tuning.sprayRadiusPoints) * 0.8, Tuning.sprayWetAmount))
        }
        for t in droplets.step(dt: dt) {
            wetCircles.append(SIMD4(t.x, t.y, t.z * 1.2, Tuning.trailWetAmount))
        }
        simulation.encodeAddWetness(wetCircles, commandBuffer: cb)
        simulation.encodeDry(dt: dt, commandBuffer: cb)
        dropRenderer.encode(droplets.droplets, into: textures.dropNormals, commandBuffer: cb)

        if now - lastProgressTime >= Tuning.progressInterval {
            lastProgressTime = now
            let progress = cleanProgress
            progressCounter.encode(dirt: textures.dirt, commandBuffer: cb) { [weak self] mean in
                // A failed readback keeps the old fraction.
                guard let mean else { return }
                DispatchQueue.main.async { self?.cleanFraction = progress.fraction(currentDirt: mean) }
            }
        }

        session.update(time: now, cleanFraction: cleanFraction, lastInputTime: lastInputTime)
        if session.phase == .finishing && previousPhase != .finishing {
            sound.playDone()
            sound.setSqueak(speed: 0)
        }
        previousPhase = session.phase

        if let screen = capture.latestTexture,
           let blur = compositor.prepareBlur(screen: screen, commandBuffer: cb),
           let rpd = view.currentRenderPassDescriptor,
           let drawable = view.currentDrawable,
           let encoder = cb.makeRenderCommandEncoder(descriptor: rpd) {
            let uniforms = CompositeUniforms(dirtOpacity: session.dirtOpacity, windowOpacity: session.windowOpacity,
                                             sparkle: session.sparkle, debugMode: debugMode)
            compositor.encode(encoder: encoder, screen: screen, blur: blur, textures: textures, uniforms: uniforms)
            if isActive {
                drawTool(now: now, encoder: encoder)
            }
            encoder.endEncoding()
            cb.present(drawable)
        }
        cb.commit()

        hud.update(fraction: cleanFraction, time: now, visible: isActive)
        if session.shouldQuit && !didQuit {
            didQuit = true
            onQuit?()
        }
    }

    /// Starts the fade-in, idle and hint timers at the first screen frame.
    private func beginSession(now: Double) {
        session = SessionController(startTime: now)
        lastFrameTime = now
        lastInputTime = now
        hud.start(at: now)
        onFirstFrame?()
    }

    /// Moves the hand and the cloth with the cursor. Call once per frame.
    private func updateHand(dt: Float) {
        let cursor = tools.cursor
        let frameVelocity = lastCursor.map { (cursor - $0) / max(dt, 0.001) } ?? .zero
        lastCursor = cursor
        clothVelocity += (frameVelocity - clothVelocity) * 0.3
        let lift: Float = tools.tool == .cloth && tools.isPressed ? 0 : 1
        clothLift += (lift - clothLift) * min(1, dt * 12)
        let twist = max(-0.3, min(0.3, clothVelocity.x * 0.00025))
        clothAngle += (twist - clothAngle) * min(1, dt * 6)

        // A soft spring with a small overshoot, so the bottle feels heavy in the hand.
        let target = cursor + Tuning.nozzleOffsetPoints
        guard var hand = handPosition, tools.tool == .bottle else {
            handPosition = target
            handVelocity = .zero
            return
        }
        let stiffness: Float = 260, damping: Float = 24
        handVelocity += ((target - hand) * stiffness - handVelocity * damping) * dt
        hand += handVelocity * dt
        handPosition = hand
    }

    /// The nozzle tip and the bottle sprite for this frame.
    private func bottlePose(now: Double) -> (nozzle: SIMD2<Float>, sprite: Sprite) {
        let hand = handPosition ?? tools.cursor + Tuning.nozzleOffsetPoints
        // Short kick back after each spray.
        let k = Float(max(0, 1 - (now - lastSprayTime) / 0.15))
        let t = Float(now - startTime)
        let idle = SIMD2<Float>(sin(t * 1.6), cos(t * 1.1)) * 1.5
        let nozzle = hand + idle + SIMD2(10, 5) * k
        // The top of the bottle lags behind fast moves. The wrist also turns a little toward the screen edges.
        let side = tools.cursor.x / space.viewSizePoints.x - 0.5
        let sway = max(-0.25, min(0.25, -handVelocity.x * 0.0003))
        let rotation = Tuning.bottleTilt + sway - side * 0.12 - 0.05 * k
        let h = Tuning.bottleHeightPoints
        let size = SIMD2<Float>(h * Float(bottle.width) / Float(bottle.height), h * (1 - 0.03 * k))
        let fromAnchor = (SIMD2<Float>(0.5, 0.5) - BottleSprite.nozzleAnchor) * size
        let c = cos(rotation), s = sin(rotation)
        let center = nozzle + SIMD2(fromAnchor.x * c - fromAnchor.y * s, fromAnchor.x * s + fromAnchor.y * c)
        return (nozzle, Sprite(center: center, size: size, rotation: rotation, alpha: 1, kind: .texture))
    }

    private func drawTool(now: Double, encoder: MTLRenderCommandEncoder) {
        let view = space.viewSizePoints
        let mistItems = mist.particles.map { p -> SIMD4<Float> in
            let pos = p.position
            return SIMD4(pos.x, pos.y, p.size, MistSystem.opacity(p))
        }
        sprites.drawMist(mistItems, viewSize: view, encoder: encoder)
        switch tools.tool {
        case .bottle:
            sprites.draw(bottlePose(now: now).sprite, texture: bottle, viewSize: view, encoder: encoder)
        case .cloth:
            let motion = SIMD4(clothVelocity.x, clothVelocity.y, Float(now - startTime), clothLift)
            let size = SIMD2<Float>(repeating: Tuning.clothSizePoints * (1 + 0.05 * clothLift))
            let rotation = clothAngle - 0.12
            // In the air the shadow moves away from the cloth.
            let shadowOffset = SIMD2<Float>(5, 8) + SIMD2(10, 14) * clothLift
            sprites.draw(Sprite(center: tools.cursor + shadowOffset, size: size * 1.04, rotation: rotation, alpha: 1,
                                kind: .clothShadow, motion: motion), texture: nil, viewSize: view, encoder: encoder)
            sprites.draw(Sprite(center: tools.cursor, size: size, rotation: rotation, alpha: 1,
                                kind: .cloth, motion: motion), texture: nil, viewSize: view, encoder: encoder)
        }
    }
}
