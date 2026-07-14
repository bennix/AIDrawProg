# Editable Flowchart Recognition Design

## Goal

Convert a hand-drawn PencilKit diagram into an editable, persistent flowchart graph. The graph contains standard teaching-oriented flowchart nodes and directed connections. Students and teachers can correct recognition results without losing the original drawing.

## Scope

The feature recognizes geometry and connectivity only. It does not perform handwriting OCR. Nodes begin without text or with manually supplied text. The editor supports the common standard teaching symbols: terminator, process, decision, input/output, subroutine, connector, document, database, manual input, display, preparation, delay, unknown, and directed arrows.

The feature does not implement execution animation or variable simulation. Those require a validated graph and remain a later increment.

## User Experience

1. A student draws as today, then taps “规整图形”.
2. The app retains the original `PKDrawing` and opens an editor containing recognized nodes and arrows.
3. Ambiguous strokes appear as an Unknown node or an unconnected endpoint. Nothing is silently discarded.
4. The editor lets the user select a node, drag it, change its symbol type, enter or edit its label, delete it, add a node, and create or remove directed connections.
5. “恢复原稿” discards only the editable graph and returns to the unmodified hand drawing.
6. “完成” saves the editable graph in the current session. Code generation renders the graph as a clean image when a graph is available; otherwise it uses the original hand drawing.
7. When generation creates a history record, it saves both original image data and the graph. Opening a record restores the graph to the editor, where subsequent edits are persisted immediately.

## Data Model

Use Codable value types stored as optional `Data` on `GenerationRecord`:

- `FlowchartGraph`: graph ID, nodes, edges, canvas size.
- `FlowchartNode`: UUID, `FlowchartNodeKind`, normalized frame, editable label, confidence, and `isUncertain`.
- `FlowchartEdge`: UUID, source node ID, target node ID, source anchor, target anchor, and optional label.
- `FlowchartNodeKind`: terminator, process, decision, inputOutput, subroutine, connector, document, database, manualInput, display, preparation, delay, unknown.
- `NormalizedRect`: Codable `Double` x/y/width/height values in the 0...1 coordinate system.

Add `var flowchartData: Data?` to `GenerationRecord`. Existing records with `nil` continue to show their original image and do not show an edit action until the user generates a graph from the drawing.

## Recognition

`FlowchartRecognizer` consumes `PKDrawing` and canvas bounds. It samples each stroke path, groups nearby or intersecting strokes, computes a group bounding box and outline descriptors, and assigns a best-effort node kind plus confidence.

- Closed, four-corner outlines classify as process or decision based on rotation.
- Circular/elliptical closed outlines classify as terminator or connector based on size.
- Slanted quadrilaterals classify as input/output, manual input, or preparation based on edge arrangement.
- Repeated oval/rectangular contours classify as database, display, or delay when their distinctive structure is detected.
- Wavy-bottom contours classify as document when detected.
- A long open stroke with an arrowhead becomes a directed edge. Its endpoints snap to the nearest node bounds within a fixed tolerance.
- No heuristic is treated as certain. Low-confidence or unmatched groups become editable Unknown nodes.

The recognizer must be deterministic, local, and dependency-free. It must never delete original strokes and must tolerate malformed paths by producing fewer nodes rather than crashing.

## Editing

`FlowchartEditorView` displays the graph on a white canvas. It provides:

- Tap node to select it and reveal an inspector.
- Drag selected node to move it; stored frames remain normalized.
- Inspector controls for node kind, label, delete, and “从此节点创建连线”.
- Tap a second node while connection mode is active to add a directed edge.
- Select an edge to delete it or edit its optional label.
- Add-node menu for every supported node kind.
- Restore-original and Done toolbar actions.

The editor is presented from the canvas area in a sheet so its gesture handling cannot conflict with PencilKit drawing. It is usable on iPhone and iPad; the inspector is a trailing panel on regular width and a bottom sheet on compact width.

## Rendering and Generation

`FlowchartRenderer` creates a white-background image from a graph. It draws node shapes, labels, anchors, and arrows using UIKit/Core Graphics. `GenerationViewModel` exports this rendered graph when a current graph exists, otherwise it uses `ImageExporter.jpegBase64` from the PencilKit drawing. The graph image data is saved in history as the record thumbnail when it was used for generation.

## Persistence

`GenerationViewModel` owns the current optional graph and current record. Edits made before the first generation stay in memory. On generation completion, graph data is stored in the new record. When an existing history record is opened, its graph data is decoded; editor saves update `record.flowchartData` and the thumbnail image data.

If graph encoding or decoding fails, the app retains the original drawing/image and shows a non-blocking error banner. No existing history record is deleted or overwritten with invalid data.

## Testing

- Unit tests for normalized frame round trips, graph Codable round trips, and node/edge mutations.
- Unit tests for deterministic rectangle, diamond, ellipse, and arrow endpoint recognition using synthetic stroke descriptors.
- Unit tests for low-confidence unknown-node fallback and nearest-node edge snapping.
- Unit tests for graph renderer output dimensions.
- UI test compilation for opening the editor, adding a node, and leaving the original drawing intact.
- Generic iOS Simulator build and test-target build after each implementation task.

## Acceptance Criteria

- The user can trigger recognition without losing the original drawing.
- Recognized nodes and directed connections are editable and can be saved.
- All listed symbol kinds can be added manually even when recognition is uncertain.
- Graph data survives app relaunch through history records.
- Code generation uses a clean graph rendering when one exists.
- Existing generation, follow-up, history, and structural-hint flows remain functional.
- The feature adds no third-party dependency.
