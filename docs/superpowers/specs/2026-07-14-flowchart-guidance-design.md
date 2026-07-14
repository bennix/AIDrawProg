# Flowchart Guidance Design

## Goal

Add a non-blocking teaching-assistance layer to AIDrawProg. Before code generation, the app identifies simple structural risks in a hand-drawn flowchart and presents a concise, encouraging Chinese hint. The same inspection summary is sent to ZenMux so the generated explanation can address possible omissions.

This first increment deliberately does not redraw shapes and does not execute the flowchart. It creates a reusable inspection result model for later shape normalization and step-by-step simulation.

## User Experience

1. The student draws a flowchart as today and taps Generate Code.
2. The app runs local inspection immediately, without a network request.
3. If it finds a concern, a yellow, non-blocking card appears above the canvas controls. The student can dismiss it or continue; generation is never blocked.
4. The card uses instructional language. Example: “可以再完善一步：图中有几处笔画似乎没有连到主流程。检查一下箭头是否连接完整。”
5. The inspection hints are appended to the AI request. The AI is instructed to verify them visually and, when applicable, explain missing branches such as a decision node without a No exit.
6. The result view continues to render the AI response unchanged. History preserves the resulting explanation as it does today.
7. Clearing the canvas clears the displayed inspection hints alongside the drawing and generated result.

## Architecture

### FlowchartInspection

Create a value type with an array of inspection messages and a `hasMessages` convenience property. Messages have a stable identifier, a severity suitable for future presentation, and Chinese display text.

### FlowchartInspector

Create a pure service that accepts `PKDrawing` and canvas bounds. Version one uses only reliable local geometry:

- Empty drawings are left to the existing generation guard and do not create a duplicate hint.
- Strokes are grouped by expanded render bounds. Separate groups indicate likely unconnected marks.
- A drawing with more than one disconnected group receives one gentle connection hint.
- Very small isolated marks receive one hint that asks the student to check whether they are accidental or unconnected.

The service does not claim to prove semantic errors such as a missing No branch from raw pen strokes. Those semantic checks remain the AI’s responsibility until structured shape recognition exists.

### GenerationViewModel

The view model publishes the latest inspection result. `generate` runs the inspector before exporting the image. The generated hint text is passed into the prompt. Existing empty-canvas, API-key, streaming, stop, history, and follow-up behavior remain unchanged.

### Prompt

The user prompt includes an optional “本地检查提示” section. The system prompt requires the model to treat it as a hypothesis, verify it against the image, avoid inventing faults, and present a gentle correction before the code when a real issue exists.

### Canvas Presentation

`ContentView` renders a dismissible `InspectionHintView` between the controls and canvas. The card is accessible, uses text rather than color alone, and remains usable in compact-width iPhone layouts.

## Future Increments

### Shape Normalization

Add an explicit “规整模式” rather than silently replacing a student’s drawing. It will recognize rectangles, diamonds, terminators, and arrows into a `FlowchartGraph` model; students can accept or reject the transformed diagram.

### Step-by-Step Simulation

Build on `FlowchartGraph` and a small, supported subset of generated programs. A Run button will animate the active node and show variable snapshots. Unsupported graphs will state why instead of fabricating execution.

## Error Handling

- Inspection failures are ignored and do not prevent generation.
- No local hint is treated as proof that a diagram is correct.
- AI request failures keep the existing error banner behavior.
- The hint is cleared when the canvas is cleared and replaced on the next generation attempt.

## Testing

- Unit-test disconnected stroke-group detection and tiny isolated-stroke detection.
- Unit-test prompt construction with and without inspection messages.
- UI-test that hints do not disable Generate Code and that Clear removes the hint.
- Build the app and test targets using the project’s generic iOS Simulator destination.

## Acceptance Criteria

- A multi-group drawing shows one supportive connection hint before the request starts.
- The student can still generate code without changing the drawing.
- AI receives the optional inspection context and is instructed to verify it.
- A canvas clear removes both inspection hints and generated output.
- iPhone and iPad layouts remain usable.
- No third-party dependencies are added.
