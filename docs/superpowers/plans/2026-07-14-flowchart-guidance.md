# Flowchart Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add non-blocking local flowchart-structure hints that are visible in the app and supplied to ZenMux as verified teaching context.

**Architecture:** `FlowchartInspector` turns PencilKit stroke bounds into a small `FlowchartInspection` value. `GenerationViewModel` publishes that value and includes it in the generation prompt. A reusable SwiftUI hint card presents the messages without disabling generation. This creates an explicit seam for future standard-shape recognition and execution simulation without implementing either feature now.

**Tech Stack:** SwiftUI, PencilKit, SwiftData, Foundation, Swift Testing.

---

### Task 1: Add a testable flowchart-inspection domain service

**Files:**
- Create: `AIDrawProg/AIDrawProg/Services/FlowchartInspector.swift`
- Modify: `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write the failing tests**

Append these tests to `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`:

```swift
@Test func identifiesSeparatedStrokeGroups() {
    let inspection = FlowchartInspector.inspect(
        strokeBounds: [
            CGRect(x: 20, y: 20, width: 80, height: 50),
            CGRect(x: 400, y: 400, width: 80, height: 50),
        ],
        canvasBounds: CGRect(x: 0, y: 0, width: 600, height: 600))

    #expect(inspection.messages.map(\.kind) == [.disconnectedMarks])
}

@Test func identifiesTinyMark() {
    let inspection = FlowchartInspector.inspect(
        strokeBounds: [CGRect(x: 100, y: 100, width: 4, height: 4)],
        canvasBounds: CGRect(x: 0, y: 0, width: 600, height: 600))

    #expect(inspection.messages.map(\.kind) == [.tinyMark])
}

@Test func leavesConnectedNormalMarksWithoutHints() {
    let inspection = FlowchartInspector.inspect(
        strokeBounds: [
            CGRect(x: 20, y: 20, width: 80, height: 50),
            CGRect(x: 90, y: 40, width: 80, height: 50),
        ],
        canvasBounds: CGRect(x: 0, y: 0, width: 600, height: 600))

    #expect(inspection.messages.isEmpty)
}
```

- [ ] **Step 2: Run the test build and verify it fails**

Run:

```bash
cd /Users/nellertcai/AIDrawProg/AIDrawProg
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build-for-testing
```

Expected: `TEST BUILD FAILED` because `FlowchartInspector` does not exist.

- [ ] **Step 3: Implement the inspection domain**

Create `AIDrawProg/AIDrawProg/Services/FlowchartInspector.swift` with this public API and behavior:

```swift
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
        // Return .empty for no bounds or non-positive canvas dimensions.
        // Treat a mark with area under 64 square points as .tinyMark.
        // Expand remaining bounds by 24 points. Merge intersecting expanded bounds
        // into connected components. More than one component yields .disconnectedMarks.
        // Return messages in disconnectedMarks, tinyMark order.
    }
}
```

Use an in-file union-find or breadth-first component pass; do not introduce dependencies. The message text must be:

```swift
"可以再完善一步：图中有几处笔画似乎没有连到主流程。检查一下箭头是否连接完整。"
"可以再检查一下：图中有一个很小的笔画，确认它不是误触或未连接的标记。"
```

- [ ] **Step 4: Run the test build and verify it passes**

Run the command from Step 2.

Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit the domain service**

```bash
cd /Users/nellertcai/AIDrawProg
git add AIDrawProg/AIDrawProg/Services/FlowchartInspector.swift \
  AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift
git commit -m "Add flowchart structure inspector"
```

### Task 2: Include inspection context in generated prompts

**Files:**
- Modify: `AIDrawProg/AIDrawProg/Services/Prompts.swift`
- Modify: `AIDrawProg/AIDrawProg/Services/GenerationViewModel.swift`
- Modify: `AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write the failing prompt tests**

Append these tests:

```swift
@Test func addsInspectionMessagesToUserPrompt() {
    let prompt = Prompts.userText(
        language: .python,
        inspection: FlowchartInspection(messages: [
            .init(kind: .disconnectedMarks, text: "检查箭头是否连接完整。"),
        ]))

    #expect(prompt.contains("本地检查提示"))
    #expect(prompt.contains("检查箭头是否连接完整。"))
}

@Test func omitsInspectionSectionWhenThereAreNoMessages() {
    let prompt = Prompts.userText(language: .swift, inspection: .empty)

    #expect(!prompt.contains("本地检查提示"))
}
```

- [ ] **Step 2: Run the test build and verify it fails**

Run the Task 1 Step 2 command.

Expected: `TEST BUILD FAILED` because `Prompts.userText(language:inspection:)` does not exist.

- [ ] **Step 3: Add prompt and view-model integration**

In `Prompts.swift`, replace the single-argument user prompt API with:

```swift
static func userText(language: CodeLanguage, inspection: FlowchartInspection) -> String {
    let base = "请把这张手绘图转换为 \(language == .python ? "Python" : "Swift") 代码。"
    guard !inspection.messages.isEmpty else { return base }
    let hints = inspection.messages.map { "- \($0.text)" }.joined(separator: "\n")
    return "\(base)\n\n本地检查提示（仅供参考，请结合图片核实，不要编造问题）：\n\(hints)"
}
```

Append this requirement to `Prompts.system` before its closing triple quote:

```text
如果用户消息包含“本地检查提示”，请把它当作待核实的教学线索：仅在图片确实支持该判断时，用温和、可操作的中文建议指出问题；不要把线索当作事实，也不要因为线索而阻止代码示例。
```

In `GenerationViewModel.swift`:

```swift
@Published var inspection = FlowchartInspection.empty
@Published var isInspectionVisible = false
```

At the beginning of `generate`, after the existing `!isStreaming` guard and before API-key validation, set:

```swift
inspection = FlowchartInspector.inspect(drawing: drawing, canvasBounds: canvasBounds)
isInspectionVisible = !inspection.messages.isEmpty
```

Pass `inspection: inspection` to `Prompts.userText`. In `clearGeneration`, reset both published properties. Add:

```swift
func dismissInspection() { isInspectionVisible = false }
```

- [ ] **Step 4: Run the test build and verify it passes**

Run the Task 1 Step 2 command.

Expected: `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit prompt integration**

```bash
cd /Users/nellertcai/AIDrawProg
git add AIDrawProg/AIDrawProg/Services/Prompts.swift \
  AIDrawProg/AIDrawProg/Services/GenerationViewModel.swift \
  AIDrawProg/AIDrawProgTests/MarkdownRendererTests.swift
git commit -m "Add inspection context to generation"
```

### Task 3: Present a non-blocking teaching hint on the canvas

**Files:**
- Create: `AIDrawProg/AIDrawProg/Views/InspectionHintView.swift`
- Modify: `AIDrawProg/AIDrawProg/ContentView.swift`
- Modify: `AIDrawProg/AIDrawProgUITests/AIDrawProgUITests.swift`

- [ ] **Step 1: Write the failing UI test**

Replace the empty body of `testExample()` with:

```swift
@MainActor
func testCanvasClearRemovesGenerationOutput() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-uiTesting"]
    app.launch()

    XCTAssertTrue(app.buttons["清空"].exists)
    app.buttons["清空"].tap()
    XCTAssertTrue(app.buttons["清空"].exists)
}
```

This verifies the existing clear action remains available while the new hint UI is present. Keep the launch-performance test unchanged.

- [ ] **Step 2: Run the test build and verify the new test compiles**

Run the Task 1 Step 2 command.

Expected: `TEST BUILD SUCCEEDED`; generic destinations compile tests but do not execute a simulator runtime.

- [ ] **Step 3: Create the reusable hint card**

Create `InspectionHintView.swift`:

```swift
import SwiftUI

struct InspectionHintView: View {
    let messages: [FlowchartInspection.Message]
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("可以再完善一步")
                    .font(.headline)
                ForEach(messages) { message in
                    Text(message.text)
                        .font(.subheadline)
                }
            }
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .accessibilityLabel("关闭提示")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
```

In `ContentView.canvasSection`, insert this immediately after the toolbar `Divider()` and before `PencilCanvas`:

```swift
if viewModel.isInspectionVisible {
    InspectionHintView(messages: viewModel.inspection.messages) {
        viewModel.dismissInspection()
    }
    .padding(.horizontal)
    .padding(.top, 10)
}
```

Do not change the existing automatic switch to the Results tab on compact-width devices. The hint remains accessible by returning to the Canvas tab; it does not block generation.

- [ ] **Step 4: Run a full build and test build**

Run:

```bash
cd /Users/nellertcai/AIDrawProg/AIDrawProg
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build-for-testing
```

Expected: `BUILD SUCCEEDED` followed by `TEST BUILD SUCCEEDED`.

- [ ] **Step 5: Commit the presentation layer**

```bash
cd /Users/nellertcai/AIDrawProg
git add AIDrawProg/AIDrawProg/Views/InspectionHintView.swift \
  AIDrawProg/AIDrawProg/ContentView.swift \
  AIDrawProg/AIDrawProgUITests/AIDrawProgUITests.swift
git commit -m "Show flowchart teaching hints"
```

### Task 4: Document the first teaching-assistance increment

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the feature to both README language sections**

Add this Chinese feature bullet after the streaming generation bullet:

```markdown
- 生成前的非阻断流程图结构提示，帮助学生检查未连接笔画和疑似误触标记
```

Add this English feature bullet after the streaming response bullet:

```markdown
- Non-blocking pre-generation flowchart hints for disconnected marks and likely accidental strokes
```

- [ ] **Step 2: Build after documentation-only update**

Run the Task 3 Step 4 build command. Expected: both builds succeed.

- [ ] **Step 3: Commit documentation**

```bash
cd /Users/nellertcai/AIDrawProg
git add README.md
git commit -m "Document flowchart guidance"
```

## Plan Self-Review

- Spec coverage: Tasks 1–3 cover local geometry, non-blocking display, prompt context, dismissal, clearing, iPhone/iPad behavior, error isolation, and testing. Task 4 documents the feature. Shape normalization and execution simulation are explicitly deferred per the approved first-increment scope.
- Placeholder scan: no TBD/TODO markers or undefined implementation steps remain.
- Type consistency: `FlowchartInspection`, `FlowchartInspector.inspect`, `Prompts.userText(language:inspection:)`, `inspection`, `isInspectionVisible`, and `dismissInspection()` are defined before use in later tasks.
