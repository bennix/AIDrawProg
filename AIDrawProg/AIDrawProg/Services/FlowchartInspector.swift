import Foundation
import PencilKit

struct FlowchartInspection: Equatable {
    enum Kind: Hashable {
        case disconnectedMarks
        case tinyMark
    }

    struct Message: Identifiable, Equatable {
        let kind: Kind
        let text: String

        var id: Kind { kind }
    }

    let messages: [Message]

    static let empty = FlowchartInspection(messages: [])
}

enum FlowchartInspector {
    static func inspect(drawing: PKDrawing, canvasBounds: CGRect) -> FlowchartInspection {
        inspect(strokeBounds: drawing.strokes.map(\.renderBounds), canvasBounds: canvasBounds)
    }

    static func inspect(strokeBounds: [CGRect], canvasBounds: CGRect) -> FlowchartInspection {
        guard canvasBounds.width > 0, canvasBounds.height > 0 else { return .empty }

        let validBounds = strokeBounds.filter { !$0.isNull && !$0.isEmpty }
        let tinyBounds = validBounds.filter { $0.width * $0.height < 64 }
        let normalBounds = validBounds.filter { $0.width * $0.height >= 64 }
        var messages: [FlowchartInspection.Message] = []

        if connectedComponentCount(for: normalBounds) > 1 {
            messages.append(.init(
                kind: .disconnectedMarks,
                text: "可以再完善一步：图中有几处笔画似乎没有连到主流程。检查一下箭头是否连接完整。"))
        }
        if !tinyBounds.isEmpty {
            messages.append(.init(
                kind: .tinyMark,
                text: "可以再检查一下：图中有一个很小的笔画，确认它不是误触或未连接的标记。"))
        }

        return FlowchartInspection(messages: messages)
    }

    private static func connectedComponentCount(for bounds: [CGRect]) -> Int {
        guard !bounds.isEmpty else { return 0 }

        var visited = Set<Int>()
        var components = 0
        let expandedBounds = bounds.map { $0.insetBy(dx: -24, dy: -24) }

        for start in expandedBounds.indices where !visited.contains(start) {
            components += 1
            var pending = [start]
            visited.insert(start)

            while let index = pending.popLast() {
                for candidate in expandedBounds.indices
                    where !visited.contains(candidate) && expandedBounds[index].intersects(expandedBounds[candidate]) {
                    visited.insert(candidate)
                    pending.append(candidate)
                }
            }
        }
        return components
    }
}
