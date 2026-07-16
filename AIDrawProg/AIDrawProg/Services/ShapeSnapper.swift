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
        /// Waypoints of a straight or elbow (single-bend) connector.
        case line([CGPoint])
        /// Same as `line`, with an arrowhead at the last waypoint.
        case arrow([CGPoint])
    }

    /// Shapes smaller than this are treated as handwriting/labels and left alone.
    static let minimumSize: CGFloat = 40
    /// Mean fit error allowed for closed shapes, relative to the shape's larger side.
    private static let closedFitTolerance: CGFloat = 0.12
    /// Lines within this angle of horizontal/vertical snap to the axis.
    private static let axisSnapAngle: CGFloat = .pi / 18
    /// Max direction change at an elbow bend. Sharper turns are arrowhead "V"s,
    /// which must stay unsnapped so they can merge with an earlier line.
    private static let elbowMaxTurn: CGFloat = .pi * 0.56

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
        // Hand-drawn loops rarely close perfectly, so allow a generous end gap.
        if span < maxDim * 0.4, length > maxDim * 1.7 {
            return classifyClosed(points: points, bounds: bounds)
        }
        return classifyOpen(points: points)
    }

    private static func classifyClosed(points: [CGPoint], bounds: CGRect) -> Shape? {
        let maxDim = max(bounds.width, bounds.height)
        let corners = cornerCount(points: points)
        // Corner count softly biases polygon-vs-ellipse: a wobbly rectangle
        // can out-fit an ellipse numerically and vice versa.
        let polygonPenalty: CGFloat = corners >= 3 ? 1 : 1.6
        let ellipsePenalty: CGFloat = corners >= 3 ? 1.6 : 1

        var candidates: [(shape: Shape, error: CGFloat)] = [
            (.rectangle(bounds), meanDistance(points, toPolygon: rectangleCorners(bounds)) * polygonPenalty),
            (.diamond(bounds), meanDistance(points, toPolygon: diamondCorners(bounds)) * polygonPenalty),
            (.ellipse(bounds), ellipseError(points, in: bounds) * ellipsePenalty),
        ]
        let skew = estimatedSkew(points: points, bounds: bounds)
        if abs(skew) > bounds.width * 0.12, abs(skew) < bounds.width * 0.45 {
            candidates.append((.parallelogram(bounds, skew: skew),
                               meanDistance(points, toPolygon: parallelogramCorners(bounds, skew: skew)) * polygonPenalty))
        }
        guard let best = candidates.min(by: { $0.error < $1.error }),
              best.error < maxDim * closedFitTolerance else { return nil }
        if case .ellipse(let rect) = best.shape, rect.height > 0, rect.width / rect.height > 2 {
            return .stadium(rect)
        }
        return best.shape
    }

    /// Counts sharp direction changes along a (nominally) closed stroke.
    private static func cornerCount(points: [CGPoint]) -> Int {
        let n = points.count
        guard n >= 12 else { return 0 }
        let step = max(3, n / 24)
        var turns = [CGFloat](repeating: 0, count: n)
        for i in 0..<n {
            let a = points[(i - step + n) % n]
            let b = points[i]
            let c = points[(i + step) % n]
            let v1 = atan2(b.y - a.y, b.x - a.x)
            let v2 = atan2(c.y - b.y, c.x - b.x)
            var diff = v2 - v1
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            turns[i] = abs(diff)
        }
        let threshold: CGFloat = .pi * 0.22
        var count = 0
        var i = 0
        while i < n {
            if turns[i] > threshold {
                let isLocalMax = ((i - step)...(i + step)).allSatisfy { turns[($0 + n) % n] <= turns[i] }
                if isLocalMax {
                    count += 1
                    i += step
                }
            }
            i += 1
        }
        return count
    }

    /// Open strokes become straight or elbow connectors, optionally with an
    /// arrowhead: the stroke is simplified to a few waypoints, a trailing
    /// doubled-back arrowhead cluster is stripped, and the remaining shaft is
    /// kept only if it is one or two clean segments.
    private static func classifyOpen(points: [CGPoint]) -> Shape? {
        let bounds = boundingRect(of: points)
        let tolerance = max(7, max(bounds.width, bounds.height) * 0.04)
        var waypoints = simplifiedWaypoints(of: points, tolerance: tolerance)
        let hasArrowhead = stripArrowhead(&waypoints)
        guard let shaft = validatedShaft(waypoints) else { return nil }
        return hasArrowhead ? .arrow(shaft) : .line(shaft)
    }

    /// Removes a trailing arrowhead: waypoints that huddle near a shaft endpoint
    /// and contain at least one sharp double-back turn.
    private static func stripArrowhead(_ waypoints: inout [CGPoint]) -> Bool {
        let count = waypoints.count
        guard count >= 3 else { return false }
        let radius = min(60, polylineLength(waypoints) * 0.35)
        for anchor in 1...(count - 2) {
            let suffix = waypoints[(anchor + 1)...]
            guard suffix.allSatisfy({ distance($0, waypoints[anchor]) <= radius }) else { continue }
            let sharpestTurn = (anchor...(count - 2)).map { directionChange(at: $0, in: waypoints) }.max() ?? 0
            guard sharpestTurn >= .pi * 0.66 else { continue }
            waypoints.removeSubrange((anchor + 1)...)
            return true
        }
        return false
    }

    /// Accepts a straight segment or a single gentle elbow, axis-snapped.
    private static func validatedShaft(_ waypoints: [CGPoint]) -> [CGPoint]? {
        guard waypoints.count == 2 || waypoints.count == 3 else { return nil }
        let lengths = zip(waypoints, waypoints.dropFirst()).map { distance($0, $1) }
        let total = lengths.reduce(0, +)
        if waypoints.count == 2 {
            guard total >= minimumSize else { return nil }
        } else {
            // Short or sharply-bent two-segment strokes are likely arrowhead
            // "V"s or handwriting, not elbow connectors.
            guard lengths.allSatisfy({ $0 >= 36 }), total >= 100,
                  directionChange(at: 1, in: waypoints) <= elbowMaxTurn else { return nil }
        }
        var snapped = [waypoints[0]]
        for point in waypoints.dropFirst() {
            snapped.append(axisSnappedEnd(from: snapped[snapped.count - 1], to: point))
        }
        return snapped
    }

    /// Douglas-Peucker simplification of a deduplicated stroke. Snapped elbow
    /// strokes repeat corner control points, which would otherwise yield
    /// zero-length segments and bogus turn angles.
    private static func simplifiedWaypoints(of points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        var deduped: [CGPoint] = []
        for point in points where deduped.last.map({ distance($0, point) > 1 }) ?? true {
            deduped.append(point)
        }
        return simplifiedPolyline(deduped, tolerance: tolerance)
    }

    private static func simplifiedPolyline(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2, let first = points.first, let last = points.last else { return points }
        var maxDistance: CGFloat = 0
        var maxIndex = 0
        for index in 1..<(points.count - 1) {
            let d = distance(from: points[index], toSegment: (first, last))
            if d > maxDistance {
                maxDistance = d
                maxIndex = index
            }
        }
        guard maxDistance > tolerance else { return [first, last] }
        let left = simplifiedPolyline(Array(points[0...maxIndex]), tolerance: tolerance)
        let right = simplifiedPolyline(Array(points[maxIndex...]), tolerance: tolerance)
        return left.dropLast() + right
    }

    private static func directionChange(at index: Int, in waypoints: [CGPoint]) -> CGFloat {
        let incoming = atan2(waypoints[index].y - waypoints[index - 1].y,
                             waypoints[index].x - waypoints[index - 1].x)
        let outgoing = atan2(waypoints[index + 1].y - waypoints[index].y,
                             waypoints[index + 1].x - waypoints[index].x)
        var diff = outgoing - incoming
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return abs(diff)
    }

    private static func polylineLength(_ waypoints: [CGPoint]) -> CGFloat {
        zip(waypoints, waypoints.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    // MARK: - Two-stroke arrows

    /// Detects an arrowhead ("V") drawn as a separate stroke near the end of an
    /// earlier straight or elbow stroke and merges the two into one arrow stroke.
    static func arrowheadMerge(headStroke: PKStroke, strokes: [PKStroke]) -> (lineIndex: Int, merged: PKStroke)? {
        let headPoints = headStroke.path.interpolatedPoints(by: .distance(4)).map(\.location)
        guard let vertex = arrowheadVertex(of: headPoints) else { return nil }
        let headBounds = boundingRect(of: headPoints)
        let headSize = max(headBounds.width, headBounds.height)

        for (index, candidate) in strokes.enumerated().reversed() {
            let points = candidate.path.interpolatedPoints(by: .distance(6)).map(\.location)
            let tolerance = max(7, max(boundingRect(of: points).width, boundingRect(of: points).height) * 0.04)
            guard let shaft = validatedShaft(simplifiedWaypoints(of: points, tolerance: tolerance)),
                  headSize < polylineLength(shaft) * 0.8 else { continue }

            let snapDistance = max(24, headSize)
            if distance(vertex, shaft[shaft.count - 1]) <= snapDistance {
                return (index, arrowStroke(along: shaft, like: candidate))
            }
            if distance(vertex, shaft[0]) <= snapDistance {
                return (index, arrowStroke(along: shaft.reversed(), like: candidate))
            }
        }
        return nil
    }

    /// The vertex of an open V-shaped stroke, or nil if it doesn't look like one.
    private static func arrowheadVertex(of points: [CGPoint]) -> CGPoint? {
        guard points.count >= 5, let first = points.first, let last = points.last else { return nil }
        let bounds = boundingRect(of: points)
        let size = max(bounds.width, bounds.height)
        guard size >= 10, size <= 150 else { return nil }

        var vertexIndex = 0
        var deviation: CGFloat = 0
        for (index, point) in points.enumerated() {
            let d = distance(from: point, toSegment: (first, last))
            if d > deviation {
                deviation = d
                vertexIndex = index
            }
        }
        guard deviation > distance(first, last) * 0.25,
              vertexIndex > 1, vertexIndex < points.count - 2 else { return nil }

        let vertex = points[vertexIndex]
        let leg1 = Array(points[0...vertexIndex])
        let leg2 = Array(points[vertexIndex...])
        guard pathLength(of: leg1) / max(distance(first, vertex), 1) < 1.25,
              pathLength(of: leg2) / max(distance(vertex, last), 1) < 1.25 else { return nil }
        return vertex
    }

    private static func arrowStroke(along waypoints: [CGPoint], like stroke: PKStroke) -> PKStroke {
        PKStroke(ink: stroke.ink,
                 path: idealPath(for: .arrow(waypoints), width: averageWidth(of: stroke)))
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
        case .line(let waypoints):
            locations = densifiedOpenPolyline(waypoints)
        case .arrow(let waypoints):
            locations = arrowPoints(along: waypoints)
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

    /// Samples an open polyline densely, repeating interior waypoints so the
    /// PencilKit spline keeps elbow bends sharp.
    private static func densifiedOpenPolyline(_ waypoints: [CGPoint]) -> [CGPoint] {
        var points: [CGPoint] = []
        for (start, end) in zip(waypoints, waypoints.dropFirst()) {
            points.append(contentsOf: [start, start])
            points.append(contentsOf: sampledSegment(start, end))
        }
        points.append(waypoints[waypoints.count - 1])
        return points
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

    private static func arrowPoints(along waypoints: [CGPoint]) -> [CGPoint] {
        let end = waypoints[waypoints.count - 1]
        let previous = waypoints[waypoints.count - 2]
        let angle = atan2(end.y - previous.y, end.x - previous.x)
        let barbLength = max(16, min(32, polylineLength(waypoints) * 0.22))
        let barbAngle: CGFloat = .pi / 6
        let leftBarb = CGPoint(x: end.x - barbLength * cos(angle - barbAngle),
                               y: end.y - barbLength * sin(angle - barbAngle))
        let rightBarb = CGPoint(x: end.x - barbLength * cos(angle + barbAngle),
                                y: end.y - barbLength * sin(angle + barbAngle))
        var points = densifiedOpenPolyline(waypoints)
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
