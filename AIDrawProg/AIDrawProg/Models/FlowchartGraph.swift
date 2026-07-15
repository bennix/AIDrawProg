import Foundation

struct NormalizedRect: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func clamped() -> NormalizedRect {
        let width = min(max(width, 0.05), 1)
        let height = min(max(height, 0.05), 1)
        return NormalizedRect(
            x: min(max(x, 0), 1 - width),
            y: min(max(y, 0), 1 - height),
            width: width,
            height: height)
    }
}

enum FlowchartNodeKind: String, Codable, CaseIterable, Identifiable {
    case terminator, process, decision, inputOutput, subroutine, connector
    case document, database, manualInput, display, preparation, delay, unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminator: "开始/结束"
        case .process: "处理"
        case .decision: "判断"
        case .inputOutput: "输入/输出"
        case .subroutine: "子过程"
        case .connector: "连接符"
        case .document: "文档"
        case .database: "数据库"
        case .manualInput: "手动输入"
        case .display: "显示"
        case .preparation: "准备"
        case .delay: "延时"
        case .unknown: "待确认"
        }
    }
}

struct FlowchartNode: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: FlowchartNodeKind
    var frame: NormalizedRect
    var label: String
    var confidence: Double

    init(id: UUID = UUID(), kind: FlowchartNodeKind, frame: NormalizedRect,
         label: String = "", confidence: Double = 1) {
        self.id = id
        self.kind = kind
        self.frame = frame.clamped()
        self.label = label
        self.confidence = confidence
    }

    var isUncertain: Bool { confidence < 0.7 || kind == .unknown }
}

enum FlowchartAnchor: String, Codable, CaseIterable {
    case top, bottom, leading, trailing
}

struct FlowchartEdge: Codable, Identifiable, Equatable {
    var id: UUID
    var sourceID: UUID
    var targetID: UUID
    var sourceAnchor: FlowchartAnchor
    var targetAnchor: FlowchartAnchor
    var label: String

    init(id: UUID = UUID(), sourceID: UUID, targetID: UUID,
         sourceAnchor: FlowchartAnchor = .bottom,
         targetAnchor: FlowchartAnchor = .top,
         label: String = "") {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.sourceAnchor = sourceAnchor
        self.targetAnchor = targetAnchor
        self.label = label
    }
}

struct FlowchartGraph: Codable, Equatable {
    var id: UUID
    var nodes: [FlowchartNode]
    var edges: [FlowchartEdge]

    init(id: UUID = UUID(), nodes: [FlowchartNode], edges: [FlowchartEdge]) {
        self.id = id
        self.nodes = nodes
        self.edges = edges
    }

}
