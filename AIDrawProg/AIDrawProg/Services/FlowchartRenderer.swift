import UIKit

enum FlowchartRenderer {
    static func image(graph: FlowchartGraph, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(edges: graph.edges, nodes: graph.nodes, size: size, context: context.cgContext)
            for node in graph.nodes {
                draw(node: node, size: size, context: context.cgContext)
            }
        }
    }

    static func jpegBase64(graph: FlowchartGraph, size: CGSize) -> String? {
        image(graph: graph, size: size).jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }

    private static func draw(edges: [FlowchartEdge], nodes: [FlowchartNode], size: CGSize, context: CGContext) {
        for edge in edges {
            guard let source = nodes.first(where: { $0.id == edge.sourceID }),
                  let target = nodes.first(where: { $0.id == edge.targetID }) else { continue }
            let start = anchor(edge.sourceAnchor, for: rect(for: source, size: size))
            let end = anchor(edge.targetAnchor, for: rect(for: target, size: size))
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(3)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            drawArrowhead(at: end, from: start, context: context)
        }
    }

    private static func draw(node: FlowchartNode, size: CGSize, context: CGContext) {
        let rect = rect(for: node, size: size)
        let path = shapePath(for: node.kind, rect: rect)
        context.setFillColor(UIColor.white.cgColor)
        context.setStrokeColor((node.isUncertain ? UIColor.systemOrange : UIColor.black).cgColor)
        context.setLineWidth(node.isUncertain ? 3 : 2.5)
        if node.isUncertain { context.setLineDash(phase: 0, lengths: [6, 4]) }
        context.addPath(path.cgPath)
        context.drawPath(using: .fillStroke)
        context.setLineDash(phase: 0, lengths: [])

        guard !node.label.isEmpty else { return }
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let textRect = rect.insetBy(dx: 8, dy: 8)
        (node.label as NSString).draw(in: textRect, withAttributes: [
            .font: UIFont.systemFont(ofSize: min(18, max(11, rect.height * 0.22))),
            .foregroundColor: UIColor.black,
            .paragraphStyle: style,
        ])
    }

    private static func shapePath(for kind: FlowchartNodeKind, rect: CGRect) -> UIBezierPath {
        switch kind {
        case .terminator:
            return UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        case .decision:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.close()
            return path
        case .inputOutput, .manualInput:
            let offset = rect.width * 0.16
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.close()
            return path
        case .connector:
            return UIBezierPath(ovalIn: rect)
        case .preparation:
            let inset = rect.width * 0.18
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.close()
            return path
        case .delay:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX, y: rect.minY), controlPoint2: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.close()
            return path
        case .document:
            let path = UIBezierPath(rect: rect)
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - 4))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - 4), controlPoint1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY + 8), controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY - 16))
            return path
        case .database:
            return UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.18)
        case .display:
            return UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.12)
        case .subroutine:
            return UIBezierPath(rect: rect)
        case .process, .unknown:
            return UIBezierPath(roundedRect: rect, cornerRadius: kind == .unknown ? 8 : 2)
        }
    }

    private static func rect(for node: FlowchartNode, size: CGSize) -> CGRect {
        CGRect(x: node.frame.x * size.width, y: node.frame.y * size.height,
               width: node.frame.width * size.width, height: node.frame.height * size.height)
    }

    private static func anchor(_ anchor: FlowchartAnchor, for rect: CGRect) -> CGPoint {
        switch anchor {
        case .top: CGPoint(x: rect.midX, y: rect.minY)
        case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
        case .leading: CGPoint(x: rect.minX, y: rect.midY)
        case .trailing: CGPoint(x: rect.maxX, y: rect.midY)
        }
    }

    private static func drawArrowhead(at end: CGPoint, from start: CGPoint, context: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 11
        context.move(to: end)
        context.addLine(to: CGPoint(x: end.x - length * cos(angle - .pi / 6), y: end.y - length * sin(angle - .pi / 6)))
        context.move(to: end)
        context.addLine(to: CGPoint(x: end.x - length * cos(angle + .pi / 6), y: end.y - length * sin(angle + .pi / 6)))
        context.strokePath()
    }
}
