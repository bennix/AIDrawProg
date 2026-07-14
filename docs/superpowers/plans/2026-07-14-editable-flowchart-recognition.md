# Editable Flowchart Recognition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform hand-drawn flowcharts into persistent, editable node-and-edge graphs while retaining the original drawing.

**Architecture:** Codable graph values represent normalized nodes and directed edges. A local PencilKit recognizer produces best-effort graph candidates with Unknown fallbacks; a SwiftUI editor corrects them. A UIKit renderer exports the graph for AI generation and persistence stores the encoded graph in `GenerationRecord`.

**Tech Stack:** SwiftUI, SwiftData, PencilKit, UIKit, Foundation, CoreGraphics, Swift Testing.

---

### Task 1: Define persistent graph values and migrate history records

**Files:**
- Create: `AIDrawProg/AIDrawProg/Models/FlowchartGraph.swift`
- Modify: `AIDrawProg/AIDrawProg/Models/GenerationRecord.swift`
- Modify: `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write failing graph round-trip and mutation tests**

Add the following tests:

```swift
@Test func graphCodableRoundTripPreservesNodesAndEdges() throws {
    let start = FlowchartNode(kind: .terminator, frame: .init(x: 0.1, y: 0.1, width: 0.2, height: 0.1))
    let process = FlowchartNode(kind: .process, frame: .init(x: 0.1, y: 0.4, width: 0.3, height: 0.12), label: "计算")
    let graph = FlowchartGraph(nodes: [start, process], edges: [.init(sourceID: start.id, targetID: process.id)])
    let restored = try JSONDecoder().decode(FlowchartGraph.self, from: JSONEncoder().encode(graph))

    #expect(restored == graph)
}

@Test func graphMovesNodeAndRemovesAttachedEdges() {
    let source = FlowchartNode(kind: .process, frame: .init(x: 0.1, y: 0.1, width: 0.2, height: 0.1))
    let target = FlowchartNode(kind: .decision, frame: .init(x: 0.5, y: 0.5, width: 0.2, height: 0.2))
    var graph = FlowchartGraph(nodes: [source, target], edges: [.init(sourceID: source.id, targetID: target.id)])

    graph.moveNode(id: source.id, to: .init(x: 0.2, y: 0.3, width: 0.2, height: 0.1))
    graph.removeNode(id: target.id)

    #expect(graph.nodes.first?.frame.x == 0.2)
    #expect(graph.edges.isEmpty)
}
```

- [ ] **Step 2: Build tests and verify the missing-model failure**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance/AIDrawProg
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build-for-testing
```

Expected: `TEST BUILD FAILED` because `FlowchartGraph` and `FlowchartNode` are absent.

- [ ] **Step 3: Implement graph values and mutation APIs**

Create `FlowchartGraph.swift` with these public types:

```swift
import Foundation

struct NormalizedRect: Codable, Equatable, Hashable {
    var x: Double; var y: Double; var width: Double; var height: Double
}

enum FlowchartNodeKind: String, Codable, CaseIterable, Identifiable {
    case terminator, process, decision, inputOutput, subroutine, connector
    case document, database, manualInput, display, preparation, delay, unknown
    var id: String { rawValue }
    var displayName: String { /* Chinese name for every case */ }
}

struct FlowchartNode: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: FlowchartNodeKind
    var frame: NormalizedRect
    var label: String = ""
    var confidence: Double = 1
    var isUncertain: Bool { confidence < 0.7 || kind == .unknown }
}

struct FlowchartEdge: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var sourceID: UUID; var targetID: UUID
    var sourceAnchor: FlowchartAnchor = .bottom
    var targetAnchor: FlowchartAnchor = .top
    var label: String = ""
}

enum FlowchartAnchor: String, Codable, CaseIterable { case top, bottom, leading, trailing }

struct FlowchartGraph: Codable, Equatable {
    var id: UUID = UUID(); var nodes: [FlowchartNode]; var edges: [FlowchartEdge]
    mutating func moveNode(id: UUID, to frame: NormalizedRect) { /* replace matching frame */ }
    mutating func removeNode(id: UUID) { /* remove node and every matching edge */ }
    mutating func addEdge(from: UUID, to: UUID) { /* append only when ids differ and edge is new */ }
}
```

Use `clamped()` helpers on `NormalizedRect` so every position and size remains in 0...1, with width/height at least `0.05`.

In `GenerationRecord`, add this optional stored property after `responseText`:

```swift
var flowchartData: Data?
```

Extend the initializer with `flowchartData: Data? = nil` and assign it. Existing SwiftData records remain valid because the new field is optional.

- [ ] **Step 4: Verify graph tests compile**

Run the Step 2 command. Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit graph persistence foundation**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance
git add AIDrawProg/AIDrawProg/Models/FlowchartGraph.swift \
  AIDrawProg/AIDrawProg/Models/GenerationRecord.swift \
  AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift
git commit -m "Add persistent flowchart graph model"
```

### Task 2: Implement deterministic node and arrow recognition

**Files:**
- Create: `AIDrawProg/AIDrawProg/Services/FlowchartRecognizer.swift`
- Modify: `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write failing descriptor recognition tests**

Test classification without constructing PencilKit strokes:

```swift
@Test func classifiesAxisAlignedQuadrilateralAsProcess() {
    #expect(FlowchartRecognizer.classify(points: [.init(0, 0), .init(100, 0), .init(100, 50), .init(0, 50), .init(0, 0)]) == .process)
}

@Test func classifiesRotatedQuadrilateralAsDecision() {
    #expect(FlowchartRecognizer.classify(points: [.init(50, 0), .init(100, 50), .init(50, 100), .init(0, 50), .init(50, 0)]) == .decision)
}

@Test func snapsArrowToNearestNodes() {
    let source = FlowchartNode(kind: .process, frame: .init(x: 0.1, y: 0.1, width: 0.2, height: 0.1))
    let target = FlowchartNode(kind: .process, frame: .init(x: 0.1, y: 0.5, width: 0.2, height: 0.1))
    let edge = FlowchartRecognizer.edge(start: .init(x: 120, y: 120), end: .init(x: 120, y: 520), nodes: [source, target], canvasSize: .init(width: 600, height: 600))

    #expect(edge?.sourceID == source.id)
    #expect(edge?.targetID == target.id)
}
```

- [ ] **Step 2: Verify the recognizer tests fail**

Run the Task 1 Step 2 command. Expected: `TEST BUILD FAILED` because `FlowchartRecognizer` is absent.

- [ ] **Step 3: Implement recognizer and Unknown fallback**

Create `FlowchartRecognizer.swift` with an internal `FlowchartPoint` (`Double` x/y) and:

```swift
enum FlowchartRecognizer {
    static func recognize(drawing: PKDrawing, canvasBounds: CGRect) -> FlowchartGraph
    static func classify(points: [FlowchartPoint]) -> FlowchartNodeKind
    static func edge(start: CGPoint, end: CGPoint, nodes: [FlowchartNode], canvasSize: CGSize) -> FlowchartEdge?
}
```

`recognize` samples each `PKStrokePath` at a fixed 6-point interval, groups intersecting expanded render bounds, and creates one node per non-arrow group. Use closed-outline point count, bounding-box ratio, corner-angle analysis, and radial variance to classify terminator/process/decision/inputOutput/subroutine/connector/document/database/manualInput/display/preparation/delay. Use `.unknown` with confidence `0.3` when no descriptor passes its threshold. Detect an arrow as a long open group whose final 20% includes two short segments diverging from the direction vector. Snap its endpoints to nearest node bounds within 48 canvas points; omit an edge when either end cannot snap.

- [ ] **Step 4: Verify recognizer tests compile**

Run the Task 1 Step 2 command. Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit recognizer**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance
git add AIDrawProg/AIDrawProg/Services/FlowchartRecognizer.swift \
  AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift
git commit -m "Recognize editable flowchart graphs"
```

### Task 3: Render graphs into clean generation images

**Files:**
- Create: `AIDrawProg/AIDrawProg/Services/FlowchartRenderer.swift`
- Modify: `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write a failing renderer-dimension test**

```swift
@Test func rendererCreatesCanvasSizedImage() {
    let graph = FlowchartGraph(nodes: [.init(kind: .process, frame: .init(x: 0.1, y: 0.1, width: 0.3, height: 0.15))], edges: [])
    let image = FlowchartRenderer.image(graph: graph, size: .init(width: 600, height: 400))

    #expect(image.size == .init(width: 600, height: 400))
}
```

- [ ] **Step 2: Verify the renderer test fails**

Run the Task 1 Step 2 command. Expected: `TEST BUILD FAILED` because `FlowchartRenderer` is absent.

- [ ] **Step 3: Implement UIKit graph rendering**

Create `FlowchartRenderer.swift` with:

```swift
import UIKit

enum FlowchartRenderer {
    static func image(graph: FlowchartGraph, size: CGSize) -> UIImage
    static func jpegBase64(graph: FlowchartGraph, size: CGSize) -> String?
}
```

Use `UIGraphicsImageRenderer` with a white background. Draw edges before nodes, using a black 3-point line and filled arrowhead. Draw every `FlowchartNodeKind` with `UIBezierPath`; use a rounded terminator, rectangle process/subroutine, diamond decision, parallelogram input/output/manual input, ellipse connector, document wave, cylinder database, display curve, hexagon preparation, D-shape delay, and dashed rounded rectangle unknown. Draw nonempty node labels centered with UIKit text attributes. Export JPEG at quality 0.8.

- [ ] **Step 4: Verify renderer test passes**

Run the Task 1 Step 2 command. Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit graph renderer**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance
git add AIDrawProg/AIDrawProg/Services/FlowchartRenderer.swift \
  AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift
git commit -m "Render editable flowchart graphs"
```

### Task 4: Build the editable graph editor

**Files:**
- Create: `AIDrawProg/AIDrawProg/Views/FlowchartEditorView.swift`
- Modify: `AIDrawProg/AIDrawProg/ContentView.swift`
- Modify: `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write a failing graph mutation test for editor actions**

```swift
@Test func graphAddsOnlyOneDirectedEdgeForSamePair() {
    let source = FlowchartNode(kind: .process, frame: .init(x: 0.1, y: 0.1, width: 0.2, height: 0.1))
    let target = FlowchartNode(kind: .process, frame: .init(x: 0.5, y: 0.5, width: 0.2, height: 0.1))
    var graph = FlowchartGraph(nodes: [source, target], edges: [])

    graph.addEdge(from: source.id, to: target.id)
    graph.addEdge(from: source.id, to: target.id)

    #expect(graph.edges.count == 1)
}
```

- [ ] **Step 2: Verify the duplicate-edge test fails**

Run the Task 1 Step 2 command. Expected: `TEST BUILD FAILED` until `addEdge` rejects duplicate pairs.

- [ ] **Step 3: Complete graph edge mutation and create editor UI**

Update `FlowchartGraph.addEdge` to ignore same-node and duplicate source-target pairs. Create `FlowchartEditorView` with this interface:

```swift
struct FlowchartEditorView: View {
    @Binding var graph: FlowchartGraph
    let restoreOriginal: () -> Void
    let save: () -> Void
}
```

Render graph nodes in a `GeometryReader`; each node uses `DragGesture` and converts its position back to `NormalizedRect`. Use `TapGesture` to select a node. The inspector contains a `Picker` over `FlowchartNodeKind.allCases`, a `TextField("节点文字")`, Delete, and “从此节点创建连线”. While connection mode is active, tapping another node calls `graph.addEdge`. The toolbar contains `Menu("添加节点")` listing every node kind, `恢复原稿`, and `完成`.

In `ContentView`, add `@State private var graph: FlowchartGraph?` and `@State private var showingFlowchartEditor = false`. Add a `规整图形` button beside the drawing tools that assigns `graph = FlowchartRecognizer.recognize(drawing: canvasView.drawing, canvasBounds: canvasView.bounds)` and presents the editor sheet. Restore sets `graph = nil`; Done dismisses. Keep the PencilKit drawing unchanged.

- [ ] **Step 4: Verify editor build**

Run the Task 1 Step 2 command. Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit editor**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance
git add AIDrawProg/AIDrawProg/Models/FlowchartGraph.swift \
  AIDrawProg/AIDrawProg/Views/FlowchartEditorView.swift \
  AIDrawProg/AIDrawProg/ContentView.swift \
  AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift
git commit -m "Add editable flowchart editor"
```

### Task 5: Persist graphs and use them for code generation

**Files:**
- Modify: `AIDrawProg/AIDrawProg/Services/GenerationViewModel.swift`
- Modify: `AIDrawProg/AIDrawProg/ContentView.swift`
- Modify: `AIDrawProg/AIDrawProg/Views/HistoryView.swift`
- Modify: `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write failing graph-data tests**

```swift
@Test func graphDataRoundTripRestoresEditableGraph() throws {
    let graph = FlowchartGraph(nodes: [.init(kind: .decision, frame: .init(x: 0.2, y: 0.2, width: 0.2, height: 0.2))], edges: [])
    let data = try JSONEncoder().encode(graph)

    #expect(try JSONDecoder().decode(FlowchartGraph.self, from: data) == graph)
}
```

- [ ] **Step 2: Verify graph-data test builds**

Run the Task 1 Step 2 command. Expected: `TEST BUILD SUCCEEDED`; this verifies the existing graph encoding contract before integration.

- [ ] **Step 3: Integrate graph generation and history persistence**

Add `@Published var currentGraph: FlowchartGraph?` to `GenerationViewModel`. Change `generate` to receive `graph: FlowchartGraph?`. When graph is nonnil, call `FlowchartRenderer.jpegBase64`, use the rendered JPEG for the request and `imageData`, and JSON-encode it into `flowchartData`; otherwise retain the existing `ImageExporter` path. Store `flowchartData` in the new `GenerationRecord`.

Update the `ContentView` generation call to pass `graph`. Clear resets `graph = nil` and calls `viewModel.clearGeneration()`.

In `HistoryDetailView`, decode `record.flowchartData`; when nonnil, show an “编辑流程图” button that presents `FlowchartEditorView`. Its save callback encodes the edited graph into `record.flowchartData`, replaces `record.imageData` with `FlowchartRenderer.image(...).jpegData(compressionQuality: 0.8)`, and dismisses. If decode fails, show a non-blocking red text message and continue to display the original image and response.

- [ ] **Step 4: Run full build and test build**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance/AIDrawProg
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build-for-testing
```

Expected: `BUILD SUCCEEDED` and `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit generation and history integration**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance
git add AIDrawProg/AIDrawProg/Services/GenerationViewModel.swift \
  AIDrawProg/AIDrawProg/ContentView.swift \
  AIDrawProg/AIDrawProg/Views/HistoryView.swift \
  AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift
git commit -m "Persist editable flowcharts in history"
```

### Task 6: Document the editor and validate all behavior

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add bilingual feature bullets**

Add under the Chinese feature list:

```markdown
- 手绘流程图可规整为可编辑的标准节点与连线；原稿保留并可恢复
```

Add under the English feature list:

```markdown
- Hand-drawn flowcharts can be normalized into editable standard nodes and directed connections while retaining the original drawing
```

- [ ] **Step 2: Run final validation**

Run the Task 5 Step 4 commands. Expected: both builds succeed without errors.

- [ ] **Step 3: Commit documentation**

```bash
cd /Users/nellertcai/AIDrawProg/.worktrees/flowchart-guidance
git add README.md
git commit -m "Document editable flowchart recognition"
```

## Plan Self-Review

- Spec coverage: Tasks 1–5 cover persistent graph values, all requested manual node kinds, best-effort local recognition, directed-edge snapping, editable nodes and connections, original-drawing restore, clean graph rendering, AI generation, history editing, and decode failures. Task 6 documents and validates the delivered behavior.
- Completeness: each task defines test code, commands, file paths, implementation interfaces, and a commit.
- Type consistency: `FlowchartGraph`, `FlowchartNode`, `FlowchartEdge`, `FlowchartRecognizer`, `FlowchartRenderer`, `FlowchartEditorView`, `currentGraph`, and `flowchartData` use the same names throughout.
