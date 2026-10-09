import Foundation

public enum Tool: Equatable {
    case bottle
    case cloth
}

/// Mouse and key input, in view points with a top-left origin.
public enum ToolInput: Equatable {
    case leftDown(SIMD2<Float>)
    case leftDragged(SIMD2<Float>)
    case leftUp(SIMD2<Float>)
    case moved(SIMD2<Float>)
    case rightDown
    case key(String)
}

public enum ToolAction: Equatable {
    case spray(SIMD2<Float>)
    case wipe(from: SIMD2<Float>, to: SIMD2<Float>)
    case toolChanged(Tool)
}

public final class ToolController {
    public private(set) var tool: Tool = .bottle
    public private(set) var cursor: SIMD2<Float> = .zero
    public private(set) var isPressed = false
    private var lastSprayTime = -Double.infinity

    public init() {}

    public func handle(_ input: ToolInput, time: Double) -> [ToolAction] {
        switch input {
        case .moved(let p):
            cursor = p
            return []
        case .leftDown(let p):
            cursor = p
            isPressed = true
            guard tool == .bottle else { return [] }
            lastSprayTime = time
            return [.spray(p)]
        case .leftDragged(let p):
            let from = cursor
            cursor = p
            guard tool == .cloth, isPressed, from != p else { return [] }
            return [.wipe(from: from, to: p)]
        case .leftUp(let p):
            cursor = p
            isPressed = false
            return []
        case .rightDown:
            return select(tool == .bottle ? .cloth : .bottle)
        case .key(let k):
            switch k {
            case " ": return select(tool == .bottle ? .cloth : .bottle)
            case "1": return select(.bottle)
            case "2": return select(.cloth)
            default: return []
            }
        }
    }

    /// Call once per frame. Repeats the spray while the bottle is held.
    public func tick(time: Double) -> [ToolAction] {
        guard tool == .bottle, isPressed, time - lastSprayTime >= 1 / Tuning.sprayRate - 1e-9 else { return [] }
        lastSprayTime = time
        return [.spray(cursor)]
    }

    private func select(_ newTool: Tool) -> [ToolAction] {
        guard newTool != tool else { return [] }
        tool = newTool
        isPressed = false
        return [.toolChanged(newTool)]
    }
}
