import Foundation
import PencilKit
import CoreGraphics

struct FlowchartPoint: Equatable {
    let x: Double
    let y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

enum FlowchartRecognizer {
    static func recognize(drawing: PKDrawing, canvasBounds: CGRect) -> FlowchartGraph {
        guard canvasBounds.width > 0, canvasBounds.height > 0 else {
            return FlowchartGraph(nodes: [], edges: [])
        }

        var nodes: [FlowchartNode] = []
        var arrows: [(start: CGPoint, end: CGPoint)] = []

        for stroke in drawing.strokes {
            let points = stroke.path.interpolatedPoints(by: .distance(8)).map {
                FlowchartPoint(Double($0.location.x), Double($0.location.y))
            }
            guard let first = points.first, let last = points.last else { continue }
            if isLikelyArrow(points) {
                arrows.append((CGPoint(x: first.x, y: first.y), CGPoint(x: last.x, y: last.y)))
                continue
            }

            let bounds = stroke.renderBounds
            guard !bounds.isEmpty else { continue }
            let kind = classify(points: points)
            let frame = NormalizedRect(
                x: Double((bounds.minX - canvasBounds.minX) / canvasBounds.width),
                y: Double((bounds.minY - canvasBounds.minY) / canvasBounds.height),
                width: Double(bounds.width / canvasBounds.width),
                height: Double(bounds.height / canvasBounds.height))
            nodes.append(FlowchartNode(
                kind: kind,
                frame: frame,
                confidence: kind == .unknown ? 0.3 : 0.75))
        }

        let edges = arrows.compactMap {
            edge(start: $0.start, end: $0.end, nodes: nodes, canvasSize: canvasBounds.size)
        }
        return FlowchartGraph(nodes: nodes, edges: edges)
    }

    static func classify(points: [FlowchartPoint]) -> FlowchartNodeKind {
        guard points.count >= 4 else { return .unknown }
        let bounds = bounds(for: points)
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let closed = distance(points[0], points[points.count - 1]) < max(width, height) * 0.18
        guard closed else { return .unknown }

        let corners = [
            FlowchartPoint(bounds.minX, bounds.minY), FlowchartPoint(bounds.maxX, bounds.minY),
            FlowchartPoint(bounds.maxX, bounds.maxY), FlowchartPoint(bounds.minX, bounds.maxY),
        ]
        let tolerance = max(width, height) * 0.18
        let hasAllCorners = corners.allSatisfy { corner in points.contains { distance($0, corner) <= tolerance } }
        if hasAllCorners { return .process }

        let center = FlowchartPoint((bounds.minX + bounds.maxX) / 2, (bounds.minY + bounds.maxY) / 2)
        let diamondVertices = [
            FlowchartPoint(center.x, bounds.minY), FlowchartPoint(bounds.maxX, center.y),
            FlowchartPoint(center.x, bounds.maxY), FlowchartPoint(bounds.minX, center.y),
        ]
        if diamondVertices.allSatisfy({ vertex in points.contains { distance($0, vertex) <= tolerance } }) {
            return .decision
        }

        let radii = points.map { distance($0, center) }
        let averageRadius = radii.reduce(0, +) / Double(radii.count)
        let variation = radii.map { abs($0 - averageRadius) }.reduce(0, +) / Double(radii.count)
        if averageRadius > 0, variation / averageRadius < 0.16 {
            return width / height > 1.7 ? .terminator : .connector
        }

        let slopes = zip(points, points.dropFirst()).map { pair -> Double in
            let dx = pair.1.x - pair.0.x
            return abs(dx) < 0.001 ? .infinity : abs((pair.1.y - pair.0.y) / dx)
        }
        if slopes.filter({ $0 > 0.15 && $0 < 4 }).count > slopes.count / 2 {
            return .inputOutput
        }
        return .unknown
    }

    static func edge(start: CGPoint, end: CGPoint, nodes: [FlowchartNode], canvasSize: CGSize) -> FlowchartEdge? {
        guard let source = nearestNode(to: start, nodes: nodes, canvasSize: canvasSize),
              let target = nearestNode(to: end, nodes: nodes, canvasSize: canvasSize),
              source.id != target.id
        else { return nil }
        return FlowchartEdge(sourceID: source.id, targetID: target.id)
    }

    private static func isLikelyArrow(_ points: [FlowchartPoint]) -> Bool {
        guard points.count >= 3, let first = points.first, let last = points.last else { return false }
        let span = distance(first, last)
        let pathLength = zip(points, points.dropFirst()).reduce(0.0) { $0 + distance($1.0, $1.1) }
        return span > 40 && pathLength / span < 1.35
    }

    private static func nearestNode(to point: CGPoint, nodes: [FlowchartNode], canvasSize: CGSize) -> FlowchartNode? {
        let candidate = nodes.min { distance(point, center(of: $0, canvasSize: canvasSize)) < distance(point, center(of: $1, canvasSize: canvasSize)) }
        guard let candidate,
              distance(point, center(of: candidate, canvasSize: canvasSize)) <= 72 else { return nil }
        return candidate
    }

    private static func center(of node: FlowchartNode, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: (node.frame.x + node.frame.width / 2) * canvasSize.width,
            y: (node.frame.y + node.frame.height / 2) * canvasSize.height)
    }

    private static func bounds(for points: [FlowchartPoint]) -> CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                      width: (xs.max() ?? 0) - (xs.min() ?? 0),
                      height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    private static func distance(_ lhs: FlowchartPoint, _ rhs: FlowchartPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
