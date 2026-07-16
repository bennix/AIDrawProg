import SwiftUI
import PencilKit

struct PencilCanvas: UIViewRepresentable {
    let canvasView: PKCanvasView
    var autoSnapEnabled: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> CanvasViewportContainer {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
        canvasView.isScrollEnabled = false
        canvasView.delegate = context.coordinator
        return CanvasViewportContainer(canvasView: canvasView)
    }

    func updateUIView(_ uiView: CanvasViewportContainer, context: Context) {
        context.coordinator.autoSnapEnabled = autoSnapEnabled
    }

    /// Watches for newly finished strokes and replaces recognizable ones with
    /// idealized flowchart shapes in place.
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var autoSnapEnabled = true
        private var knownStrokeCount = 0
        private var isReplacingStroke = false

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let strokes = canvasView.drawing.strokes
            defer { knownStrokeCount = strokes.count }
            guard autoSnapEnabled,
                  !isReplacingStroke,
                  strokes.count == knownStrokeCount + 1,
                  let finished = strokes.last,
                  let snapped = ShapeSnapper.snappedStroke(for: finished) else { return }

            isReplacingStroke = true
            let original = canvasView.drawing
            var drawing = original
            drawing.strokes[drawing.strokes.count - 1] = snapped
            canvasView.drawing = drawing
            // Undo restores the hand-drawn stroke instead of dropping the shape.
            canvasView.undoManager?.registerUndo(withTarget: canvasView) { target in
                target.drawing = original
            }
            isReplacingStroke = false
        }
    }
}

/// A large virtual workspace. The scroll view owns navigation gestures while
/// PKCanvasView remains untransformed, preventing redraw flashes during strokes.
final class CanvasViewportContainer: UIScrollView, UIScrollViewDelegate {
    // A tiled PencilKit view remains responsive at this size while still providing
    // several screenfuls of space in every direction from the initial center.
    private let workspaceSize = CGSize(width: 4_096, height: 4_096)
    private let canvasView: PKCanvasView
    private var hasPositionedInitialViewport = false

    init(canvasView: PKCanvasView) {
        self.canvasView = canvasView
        super.init(frame: .zero)
        backgroundColor = .white
        delegate = self
        minimumZoomScale = 0.5
        maximumZoomScale = 3
        bouncesZoom = true
        alwaysBounceHorizontal = true
        alwaysBounceVertical = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        delaysContentTouches = false
        // Native scroll/zoom gestures give system-level smoothness (momentum,
        // anchored pinch). Single-finger touches still draw because the pan
        // gesture only recognizes with two fingers; when it does, cancelling
        // content touches discards any stray stroke start.
        canCancelContentTouches = true
        panGestureRecognizer.minimumNumberOfTouches = 2
        panGestureRecognizer.maximumNumberOfTouches = 2

        canvasView.frame = CGRect(origin: .zero, size: workspaceSize)
        addSubview(canvasView)
        contentSize = workspaceSize

        let reset = UITapGestureRecognizer(target: self, action: #selector(resetViewport))
        reset.numberOfTapsRequired = 2
        reset.numberOfTouchesRequired = 2
        addGestureRecognizer(reset)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasPositionedInitialViewport, bounds.width > 0, bounds.height > 0 else { return }
        hasPositionedInitialViewport = true
        contentOffset = centeredOffset()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        canvasView
    }

    @objc private func resetViewport() {
        setZoomScale(1, animated: true)
        setContentOffset(centeredOffset(), animated: true)
    }

    private func centeredOffset() -> CGPoint {
        CGPoint(x: (workspaceSize.width - bounds.width) / 2,
                y: (workspaceSize.height - bounds.height) / 2)
    }
}
