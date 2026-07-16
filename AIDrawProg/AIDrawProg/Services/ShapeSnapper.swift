import PencilKit
import CoreGraphics

/// Recognizes a completed hand-drawn stroke as a standard flowchart shape and
/// builds an idealized replacement stroke that covers the same canvas area.
/// The replacement is a plain PKStroke, so it pans/zooms/erases/undoes exactly
/// like hand-drawn ink.
enum ShapeSnapper {
    enum Shape: Equatable {
        case rectangle(CGRect)
        case parallelogram(CGRect, skew: CGFloat)
        case diamond(CGRect)
        case ellipse(CGRect)
        case stadium(CGRect)
        case line(from: CGPoint, to: CGPoint)
        case arrow(from: CGPoint, to: CGPoint)
    }

    /// Shapes smaller than this are treated as handwriting/labels and left alone.
    static let minimumSize: CGFloat = 40
    /// Mean fit error allowed for closed shapes, relative to the shape's larger side.
    private static let closedFitTolerance: CGFloat = 0.09
    /// Path-length / endpoint-span ratio below which an open stroke counts as straight.
    private static let straightnessTolerance: CGFloat = 1.08
    /// Lines within this angle of horizontal/vertical snap to the axis.
    private static let axisSnapAngle: CGFloat = .pi / 18

    // MARK: - Entry point

    static func snappedStroke(for stroke: PKStroke) -> PKStroke? {
        let locations = stroke.path.interpolatedPoints(by: .distance(6)).map(\.location)
        guard let shape = classify(points: locations) else { return nil }
        return PKStroke(ink: stroke.ink, path: idealPath(for: shape, width: averageWidth(of: stroke)))
    }

    // MARK: - Classification

    static func classify(points: [CGPoint]) -> Shape? {
        guard points.count >= 4, let first = points.first, let last = points.last else { return nil }
        let bounds = boundingRect(of: points)
        let maxDim = max(bounds.width, bounds.height)
        guard maxDim >= minimumSize else { return nil }

        let span = distance(first, last)
        let length = pathLength(of: points)
        if span < maxDim * 0.25, length > maxDim * 2 {
            return classifyClosed(points: points, bounds: bounds)
        }
        return classifyOpen(points: points, span: span, length: length)
    }

    private static func classifyClosed(points: [CGPoint], bounds: CGRect) -> Shape? {
        let maxDim = max(bounds.width, bounds.height)
        var candidates: [(shape: Shape, error: CGFloat)] = [
            (.rectangle(bounds), meanDistance(points, toPolygon: rectangleCorners(bounds))),
            (.diamond(bounds), meanDistance(points, toPolygon: diamondCorners(bounds))),
            (.ellipse(bounds), ellipseError(points, in: bounds)),
        ]
        let skew = estimatedSkew(points: points, bounds: bounds)
        if abs(skew) > bounds.width * 0.12, abs(skew) < bounds.width * 0.45 {
            candidates.append((.parallelogram(bounds, skew: skew),
                               meanDistance(points, toPolygon: parallelogramCorners(bounds, skew: skew))))
        }
        guard let best = candidates.min(by: { $0.error < $1.error }),
              best.error < maxDim * closedFitTolerance else { return nil }
        if case .ellipse(let rect) = best.shape, rect.height > 0, rect.width / rect.height > 2 {
            return .stadium(rect)
        }
        return best.shape
    }

    private static func classifyOpen(points: [CGPoint], span: CGFloat, length: CGFloat) -> Shape? {
        guard let first = points.first, let last = points.last, span > 0 else { return nil }
        if length / span < straightnessTolerance {
            return .line(from: first, to: axisSnappedEnd(from: first, to: last))
        }
        return arrowShape(points: points)
    }

    /// A single-stroke arrow: a straight shaft followed by a short doubled-back
    /// tail near the tip (the hand-drawn arrowhead).
    private static func arrowShape(points: [CGPoint]) -> Shape? {
        guard let first = points.first else { return nil }
        let distances = points.map { distance(first, $0) }
        guard let tipDistance = distances.max(), tipDistance >= minimumSize else { return nil }
        // The stroke may revisit the tip while drawing the arrowhead, so take
        // the first point that reaches (almost) the farthest distance.
        guard let tipIndex = distances.firstIndex(where: { $0 >= tipDistance * 0.98 }),
              tipIndex >= 2, tipIndex < points.count - 1 else { return nil }

        let shaft = Array(points[0...tipIndex])
        guard pathLength(of: shaft) / tipDistance < 1.12 else { return nil }

        let tip = points[tipIndex]
        let tail = Array(points[tipIndex...])
        let tailLength = pathLength(of: tail)
        guard tailLength > 12, tailLength < tipDistance * 0.6,
              tail.allSatisfy({ distance($0, tip) < tipDistance * 0.45 }) else { return nil }
        return .arrow(from: first, to: axisSnappedEnd(from: first, to: tip))
    }

    private static func axisSnappedEnd(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(abs(dy), abs(dx))
        if angle < axisSnapAngle { return CGPoint(x: end.x, y: start.y) }
        if .pi / 2 - angle < axisSnapAngle { return CGPoint(x: start.x, y: end.y) }
        return end
    }

    // MARK: - Fit errors

    private static func meanDistance(_ points: [CGPoint], toPolygon corners: [CGPoint]) -> CGFloat {
        guard !corners.isEmpty else { return .greatestFiniteMagnitude }
        var total: CGFloat = 0
        for point in points {
            var nearest = CGFloat.greatestFiniteMagnitude
            for index in corners.indices {
                let next = corners[(index + 1) % corners.count]
                nearest = min(nearest, distance(from: point, toSegment: (corners[index], next)))
            }
            total += nearest
        }
        return total / CGFloat(points.count)
    }

    private static func ellipseError(_ points: [CGPoint], in bounds: CGRect) -> CGFloat {
        let a = max(bounds.width / 2, 1)
        let b = max(bounds.height / 2, 1)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let scale = min(a, b)
        var total: CGFloat = 0
        for point in points {
            let r = hypot((point.x - center.x) / a, (point.y - center.y) / b)
            total += abs(r - 1) * scale
        }
        return total / CGFloat(points.count)
    }

    /// Horizontal offset between the top and bottom edges of a closed stroke,
    /// used to tell parallelograms apart from rectangles.
    private static func estimatedSkew(points: [CGPoint], bounds: CGRect) -> CGFloat {
        let band = bounds.height * 0.3
        let topXs = points.filter { $0.y < bounds.minY + band }.map(\.x)
        let bottomXs = points.filter { $0.y > bounds.maxY - band }.map(\.x)
        guard !topXs.isEmpty, !bottomXs.isEmpty else { return 0 }
        let topCenter = topXs.reduce(0, +) / CGFloat(topXs.count)
        let bottomCenter = bottomXs.reduce(0, +) / CGFloat(bottomXs.count)
        return topCenter - bottomCenter
    }

    // MARK: - Ideal stroke generation

    private static func idealPath(for shape: Shape, width: CGFloat) -> PKStrokePath {
        let locations: [CGPoint]
        switch shape {
        case .rectangle(let rect):
            locations = densifiedPolygon(rectangleCorners(rect))
        case .parallelogram(let rect, let skew):
            locations = densifiedPolygon(parallelogramCorners(rect, skew: skew))
        case .diamond(let rect):
            locations = densifiedPolygon(diamondCorners(rect))
        case .ellipse(let rect):
            locations = ellipsePerimeter(rect)
        case .stadium(let rect):
            locations = stadiumPerimeter(rect)
        case .line(let start, let end):
            locations = densifiedSegment(start, end)
        case .arrow(let start, let end):
            locations = arrowPoints(from: start, to: end)
        }
        let controlPoints = locations.enumerated().map { index, location in
            PKStrokePoint(location: location,
                          timeOffset: TimeInterval(index) * 0.01,
                          size: CGSize(width: width, height: width),
                          opacity: 1,
                          force: 1,
                          azimuth: 0,
                          altitude: .pi / 2)
        }
        return PKStrokePath(controlPoints: controlPoints, creationDate: Date())
    }

    private static func averageWidth(of stroke: PKStroke) -> CGFloat {
        let widths = stroke.path.map(\.size.width)
        guard !widths.isEmpty else { return 5 }
        return widths.reduce(0, +) / CGFloat(widths.count)
    }

    private static func rectangleCorners(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    private static func diamondCorners(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY),
         CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY)]
    }

    private static func parallelogramCorners(_ rect: CGRect, skew: CGFloat) -> [CGPoint] {
        let offset = abs(skew)
        if skew > 0 {
            return [CGPoint(x: rect.minX + offset, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                    CGPoint(x: rect.maxX - offset, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        }
        return [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX - offset, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX + offset, y: rect.maxY)]
    }

    /// Samples a closed polygon densely so the PencilKit spline hugs the edges,
    /// repeating each corner so it stays sharp.
    private static func densifiedPolygon(_ corners: [CGPoint]) -> [CGPoint] {
        var points: [CGPoint] = []
        for index in corners.indices {
            let start = corners[index]
            let end = corners[(index + 1) % corners.count]
            points.append(contentsOf: [start, start, start])
            points.append(contentsOf: sampledSegment(start, end))
        }
        let first = corners[0]
        points.append(contentsOf: [first, first, first])
        return points
    }

    private static func densifiedSegment(_ start: CGPoint, _ end: CGPoint) -> [CGPoint] {
        [start] + sampledSegment(start, end) + [end]
    }

    private static func sampledSegment(_ start: CGPoint, _ end: CGPoint) -> [CGPoint] {
        let length = distance(start, end)
        let steps = max(2, Int(length / 4))
        return (0...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: start.x + (end.x - start.x) * t,
                           y: start.y + (end.y - start.y) * t)
        }
    }

    private static func ellipsePerimeter(_ rect: CGRect) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a = rect.width / 2
        let b = rect.height / 2
        let steps = 72
        var points = (0...steps).map { step -> CGPoint in
            let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
            return CGPoint(x: center.x + a * cos(t), y: center.y + b * sin(t))
        }
        points.append(points[0])
        return points
    }

    private static func stadiumPerimeter(_ rect: CGRect) -> [CGPoint] {
        let radius = rect.height / 2
        let leftCenter = CGPoint(x: rect.minX + radius, y: rect.midY)
        let rightCenter = CGPoint(x: rect.maxX - radius, y: rect.midY)
        var points: [CGPoint] = []
        points.append(contentsOf: sampledSegment(CGPoint(x: leftCenter.x, y: rect.minY),
                                                 CGPoint(x: rightCenter.x, y: rect.minY)))
        points.append(contentsOf: arcPoints(center: rightCenter, radius: radius,
                                            from: -.pi / 2, to: .pi / 2))
        points.append(contentsOf: sampledSegment(CGPoint(x: rightCenter.x, y: rect.maxY),
                                                 CGPoint(x: leftCenter.x, y: rect.maxY)))
        points.append(contentsOf: arcPoints(center: leftCenter, radius: radius,
                                            from: .pi / 2, to: 3 * .pi / 2))
        points.append(points[0])
        return points
    }

    private static func arcPoints(center: CGPoint, radius: CGFloat,
                                  from startAngle: CGFloat, to endAngle: CGFloat) -> [CGPoint] {
        let steps = 24
        return (0...steps).map { step -> CGPoint in
            let t = startAngle + (endAngle - startAngle) * CGFloat(step) / CGFloat(steps)
            return CGPoint(x: center.x + radius * cos(t), y: center.y + radius * sin(t))
        }
    }

    private static func arrowPoints(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let span = distance(start, end)
        let barbLength = max(16, min(32, span * 0.22))
        let barbAngle: CGFloat = .pi / 6
        let leftBarb = CGPoint(x: end.x - barbLength * cos(angle - barbAngle),
                               y: end.y - barbLength * sin(angle - barbAngle))
        let rightBarb = CGPoint(x: end.x - barbLength * cos(angle + barbAngle),
                                y: end.y - barbLength * sin(angle + barbAngle))
        var points = densifiedSegment(start, end)
        points.append(contentsOf: [end, end])
        points.append(contentsOf: sampledSegment(end, leftBarb))
        points.append(contentsOf: [leftBarb, leftBarb])
        points.append(contentsOf: sampledSegment(leftBarb, end))
        points.append(contentsOf: [end, end])
        points.append(contentsOf: sampledSegment(end, rightBarb))
        points.append(rightBarb)
        return points
    }

    // MARK: - Geometry helpers

    private static func boundingRect(of points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY,
                      width: (xs.max() ?? 0) - minX,
                      height: (ys.max() ?? 0) - minY)
    }

    private static func pathLength(of points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func distance(from point: CGPoint, toSegment segment: (CGPoint, CGPoint)) -> CGFloat {
        let (a, b) = segment
        let abX = b.x - a.x
        let abY = b.y - a.y
        let lengthSquared = abX * abX + abY * abY
        guard lengthSquared > 0 else { return distance(point, a) }
        let t = max(0, min(1, ((point.x - a.x) * abX + (point.y - a.y) * abY) / lengthSquared))
        return distance(point, CGPoint(x: a.x + abX * t, y: a.y + abY * t))
    }
}
