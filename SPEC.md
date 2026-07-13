# SPEC：AIDrawProg v1.0 — 手绘流程图转代码 iOS 应用

> 本文档是唯一需求来源。执行者（AI 或人类）必须严格按本文档实施。
> 与本文档冲突的任何"优化想法"一律不允许。

---

## 0. 执行者必读：防呆规则（最高优先级）

### 0.1 硬性禁令 —— 违反任何一条即视为任务失败

1. **禁止**添加任何第三方依赖（SPM、CocoaPods、Carthage 一律禁止）。本项目零依赖。
2. **禁止**修改 `AIDrawProg.xcodeproj/project.pbxproj`、`Assets.xcassets`、部署目标（保持 iOS 26.5）、签名配置、Info 配置。本项目使用 Xcode filesystem-synchronized groups：**在源码目录新建 .swift 文件会自动加入编译目标，不需要动工程文件**。
3. **禁止**修改本 SPEC 中标注 `【逐字复制】` 的代码——一个字符都不许改（包括注释、空行、颜色数值）。
4. **禁止**引入 SPEC 未提及的框架。允许 import 的全集：`SwiftUI`、`SwiftData`、`PencilKit`、`Foundation`、`UIKit`、`Security`、`Combine`。
5. **禁止**跳过阶段门禁（见 0.3）。禁止"先写完所有代码最后统一编译"。
6. **禁止**为了让编译通过而注释掉代码、删除功能、或用空实现糊弄。
7. 遇到本 SPEC 没有写明的决策点：**停下来向人类提问**，不要自己猜。

### 0.2 路径与环境

- 仓库根目录：`/Users/nellertcai/AIDrawProg`
- Xcode 工程：`/Users/nellertcai/AIDrawProg/AIDrawProg/AIDrawProg.xcodeproj`
- **源码目录（所有新文件放这里或其子目录）**：`/Users/nellertcai/AIDrawProg/AIDrawProg/AIDrawProg/`
- 子目录 `Models/`、`Services/`、`Views/` 需要自己创建（直接 mkdir，文件系统同步组会自动识别）。

### 0.3 阶段门禁协议

本 SPEC 共 6 个阶段，**必须按顺序串行执行**。每个阶段结尾必须运行以下命令并把输出粘贴到工作记录中：

```bash
cd /Users/nellertcai/AIDrawProg/AIDrawProg && \
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

输出中必须出现 `BUILD SUCCEEDED` 才允许进入下一阶段。同时逐项自查该阶段的验收清单并打勾（`- [x]`）。

### 0.4 失败协议

- 同一个编译错误连续修复 **3 次**仍失败 → 立即停止，把完整错误信息原样粘贴出来，报告人类。
- 不确定某个 API 是否存在 → 不要臆造，停下来报告。
- 每阶段完成后 git commit 一次，message 格式：`Phase N: <阶段名>`。

---

## 1. 产品概述

**用户**：学习程序设计的学生。
**核心流程**：在画布上用手指或 Apple Pencil 画流程图/示意图 → 选择目标语言（Python/Swift）和模型 → 点「生成代码」→ AI 流式返回「图的理解 + 代码块 + 逐步解释」→ 代码带语法高亮，可一键拷贝 → 记录自动存入历史。

**AI 平台**：ZenMux（OpenAI 兼容 API）。
- Base URL：`https://zenmux.ai/api/v1`（固定常量，不提供 UI 修改）
- 默认模型：`anthropic/claude-sonnet-4.6`、`openai/gpt-5.4`（都支持图像输入）
- API Key：用户在设置页输入，Keychain 永久保存，UI 掩码显示
- 无 Key 时引导注册：邀请链接 `https://zenmux.ai/invite/GBQMC5`

**布局**：
- iPad 横屏（regular 宽度）：左画布、右结果，各占一半。
- iPhone / 紧凑宽度：TabView 两个 Tab（画布 / 结果），生成开始时自动切到结果 Tab。
- 全局导航：工具栏含「历史」和「设置」入口（`NavigationStack` + sheet 或 push 均可）。

---

## 2. 阶段 1：清理模板 + 数据与设置层

### 2.1 操作步骤

1. 创建目录 `Models/`、`Services/`、`Views/`。
2. **删除** `Item.swift`。
3. 用 2.2 的代码**整体替换** `AIDrawProgApp.swift` 的内容。
4. 用 2.3 的代码**整体替换** `ContentView.swift` 的内容（临时占位，阶段 3 会重写）。
5. 新建 `Models/GenerationRecord.swift`（2.4）、`Models/AppSettings.swift`（2.5）、`Services/KeychainHelper.swift`（2.6）。

### 2.2 `AIDrawProgApp.swift` 【逐字复制】

```swift
import SwiftUI
import SwiftData

@main
struct AIDrawProgApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
        .modelContainer(for: GenerationRecord.self)
    }
}
```

### 2.3 `ContentView.swift`（阶段 1 临时占位）【逐字复制】

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("AIDrawProg - Phase 1")
    }
}
```

### 2.4 `Models/GenerationRecord.swift` 【逐字复制】

```swift
import Foundation
import SwiftData

@Model
final class GenerationRecord {
    var createdAt: Date
    var modelName: String
    var language: String
    @Attribute(.externalStorage) var imageData: Data
    var responseText: String

    init(createdAt: Date = .now, modelName: String, language: String,
         imageData: Data, responseText: String) {
        self.createdAt = createdAt
        self.modelName = modelName
        self.language = language
        self.imageData = imageData
        self.responseText = responseText
    }
}
```

### 2.5 `Models/AppSettings.swift` 【逐字复制】

```swift
import Foundation
import Combine

/// 模型列表与当前选中模型（UserDefaults 持久化）。
/// API Key 不在此处 —— 见 KeychainHelper。
final class AppSettings: ObservableObject {
    static let defaultModels = ["anthropic/claude-sonnet-4.6", "openai/gpt-5.4"]
    static let baseURL = "https://zenmux.ai/api/v1"
    static let inviteURL = "https://zenmux.ai/invite/GBQMC5"

    private let modelsKey = "zenmux_models"
    private let selectedKey = "zenmux_selected_model"

    @Published var models: [String] {
        didSet { UserDefaults.standard.set(models, forKey: modelsKey) }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: selectedKey) }
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: modelsKey)
        let models = (saved?.isEmpty == false) ? saved! : Self.defaultModels
        self.models = models
        let savedSelected = UserDefaults.standard.string(forKey: selectedKey)
        self.selectedModel = (savedSelected.flatMap { models.contains($0) ? $0 : nil }) ?? models[0]
    }

    /// 添加模型。返回 false 表示被拒绝（空白或重复）。
    @discardableResult
    func addModel(_ raw: String) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !models.contains(name) else { return false }
        models.append(name)
        return true
    }

    /// 删除模型。防呆：至少保留 1 个；删除当前选中项时回落到第一项。
    func removeModel(at offsets: IndexSet) {
        guard models.count > 1 else { return }
        let removed = offsets.map { models[$0] }
        models.remove(atOffsets: offsets)
        if removed.contains(selectedModel) {
            selectedModel = models[0]
        }
    }
}
```

### 2.6 `Services/KeychainHelper.swift` 【逐字复制】

```swift
import Foundation
import Security

enum KeychainHelper {
    private static let service = Bundle.main.bundleIdentifier ?? "AIDrawProg"
    private static let account = "zenmux_api_key"

    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty
        else { return nil }
        return key
    }

    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### 2.7 阶段 1 验收清单

- [ ] `Item.swift` 已删除，无残留引用
- [ ] 5 个文件内容与 SPEC 逐字一致
- [ ] 阶段门禁命令输出 `BUILD SUCCEEDED`（粘贴输出）
- [ ] git commit：`Phase 1: 数据与设置层`

---

## 3. 阶段 2：服务层（网络 / 解析 / 高亮 / 图像 / Prompt）

新建 5 个文件，全部【逐字复制】。

### 3.1 `Services/ResponseParser.swift` 【逐字复制】

```swift
import Foundation

enum CodeLanguage: String {
    case python
    case swift
}

/// 把 AI 回复按 ``` 围栏切分为交替的文字段与代码段。
/// 流式期间可反复调用：未闭合的围栏视为「进行中的代码段」。
enum ResponseParser {
    enum Segment: Identifiable, Equatable {
        case text(id: Int, content: String)
        case code(id: Int, content: String, language: CodeLanguage?)

        var id: Int {
            switch self {
            case .text(let id, _): return id
            case .code(let id, _, _): return id
            }
        }
    }

    static func parse(_ response: String) -> [Segment] {
        var segments: [Segment] = []
        var isCode = false
        var language: CodeLanguage?
        var buffer: [String] = []
        var nextID = 0

        func flush() {
            let content = buffer.joined(separator: "\n")
            buffer = []
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if isCode {
                segments.append(.code(id: nextID, content: content, language: language))
            } else {
                segments.append(.text(id: nextID, content: content))
            }
            nextID += 1
        }

        for line in response.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                flush()
                if isCode {
                    isCode = false
                    language = nil
                } else {
                    isCode = true
                    let tag = trimmed.dropFirst(3).lowercased()
                    language = CodeLanguage(rawValue: String(tag))
                }
            } else {
                buffer.append(line)
            }
        }
        flush()
        return segments
    }
}
```

### 3.2 `Services/Prompts.swift` 【逐字复制】

```swift
import Foundation

enum Prompts {
    static let system = """
    你是一位耐心的编程教师，面向初学编程的学生。用户会给你一张手绘的流程图或程序示意图。
    请严格按以下结构用中文回答：
    1. 先用 2-3 句话说明你从图中理解到的程序逻辑；
    2. 给出一个完整、可直接运行的代码块，必须使用围栏格式（```python 或 ```swift）；
    3. 逐步解释这段代码，语言通俗，面向初学者。
    如果图片无法辨认为程序逻辑，请直接说明原因，并建议学生如何画得更清楚。此时不要编造代码。
    """

    static func userText(language: CodeLanguage) -> String {
        "请把这张手绘图转换为 \(language == .python ? "Python" : "Swift") 代码。"
    }
}
```

### 3.3 `Services/ZenMuxClient.swift` 【逐字复制】

```swift
import Foundation

struct ZenMuxError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ZenMux {
    /// 流式调用 ZenMux chat/completions，逐块产出正文文本。
    static func streamCompletion(
        apiKey: String,
        model: String,
        systemPrompt: String,
        userText: String,
        imageBase64JPEG: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: URL(string: AppSettings.baseURL + "/chat/completions")!)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 60
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": [
                                ["type": "text", "text": userText],
                                ["type": "image_url",
                                 "image_url": ["url": "data:image/jpeg;base64,\(imageBase64JPEG)"]],
                            ]],
                        ],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ZenMuxError(message: "无效的服务器响应")
                    }
                    guard http.statusCode == 200 else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        let text = String(data: data, encoding: .utf8) ?? ""
                        switch http.statusCode {
                        case 401:
                            throw ZenMuxError(message: "API Key 无效，请到设置页检查（HTTP 401）")
                        case 429:
                            throw ZenMuxError(message: "请求过于频繁或额度不足，请稍后再试（HTTP 429）")
                        default:
                            throw ZenMuxError(message: "请求失败（HTTP \(http.statusCode)）：\(text.prefix(200))")
                        }
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard
                            let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                            let choices = json["choices"] as? [[String: Any]],
                            let delta = choices.first?["delta"] as? [String: Any],
                            let content = delta["content"] as? String,
                            !content.isEmpty
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

### 3.4 `Services/SyntaxHighlighter.swift` 【逐字复制】

```swift
import SwiftUI

enum SyntaxHighlighter {
    private static let pythonKeywords =
        "def|return|if|elif|else|for|while|in|not|and|or|import|from|as|class|try|except|finally|with|pass|break|continue|lambda|None|True|False|print|range|len|input|int|str|float|list|dict"
    private static let swiftKeywords =
        "func|return|if|else|for|while|in|var|let|class|struct|enum|import|guard|switch|case|default|break|continue|nil|true|false|print|String|Int|Double|Bool|Array|Dictionary|self|init|throws|try|catch|do"

    static func highlight(_ code: String, language: CodeLanguage?) -> AttributedString {
        var attributed = AttributedString(code)
        attributed.foregroundColor = Color(white: 0.9)

        let keywords = (language == .swift) ? swiftKeywords : pythonKeywords
        let commentPattern = (language == .swift) ? "//[^\\n]*" : "#[^\\n]*"

        // 顺序重要：后面的规则会覆盖前面的着色
        let rules: [(pattern: String, color: Color)] = [
            ("\\b\\d+(\\.\\d+)?\\b", .orange),
            ("\\b(\(keywords))\\b", Color(red: 1.0, green: 0.5, blue: 0.7)),
            ("\"[^\"\\n]*\"", Color(red: 1.0, green: 0.8, blue: 0.4)),
            ("'[^'\\n]*'", Color(red: 1.0, green: 0.8, blue: 0.4)),
            (commentPattern, Color(red: 0.5, green: 0.75, blue: 0.5)),
        ]

        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            let fullRange = NSRange(code.startIndex..., in: code)
            for match in regex.matches(in: code, range: fullRange) {
                guard let stringRange = Range(match.range, in: code),
                      let attrRange = Range(stringRange, in: attributed) else { continue }
                attributed[attrRange].foregroundColor = rule.color
            }
        }
        return attributed
    }
}
```

### 3.5 `Services/ImageExporter.swift` 【逐字复制】

```swift
import UIKit
import PencilKit

enum ImageExporter {
    /// 把画布内容渲染为白底 JPEG，最长边不超过 1568pt，返回 base64 字符串。
    /// 画布为空时返回 nil（调用方应先用 drawing.strokes.isEmpty 拦截）。
    static func jpegBase64(from drawing: PKDrawing, canvasBounds: CGRect) -> String? {
        guard !drawing.strokes.isEmpty,
              canvasBounds.width > 0, canvasBounds.height > 0 else { return nil }
        let source = drawing.image(from: canvasBounds, scale: 2)

        let maxSide: CGFloat = 1568
        let longest = max(source.size.width, source.size.height)
        let ratio = longest > maxSide ? maxSide / longest : 1
        let targetSize = CGSize(width: source.size.width * ratio,
                                height: source.size.height * ratio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }
}
```

### 3.6 阶段 2 验收清单

- [ ] 5 个文件内容与 SPEC 逐字一致
- [ ] 阶段门禁命令输出 `BUILD SUCCEEDED`（粘贴输出）
- [ ] git commit：`Phase 2: 服务层`

---

## 4. 阶段 3：画布 + 生成编排 + 主布局

### 4.1 `Services/GenerationViewModel.swift` 【逐字复制】

```swift
import SwiftUI
import PencilKit
import SwiftData

@MainActor
final class GenerationViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case streaming
        case finished
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var responseText: String = ""
    @Published var needsAPIKey = false

    private var task: Task<Void, Never>?

    var isStreaming: Bool { phase == .streaming }

    func generate(drawing: PKDrawing, canvasBounds: CGRect,
                  language: CodeLanguage, model: String,
                  modelContext: ModelContext) {
        guard !isStreaming else { return }
        guard KeychainHelper.loadAPIKey() != nil else {
            needsAPIKey = true
            return
        }
        guard !drawing.strokes.isEmpty,
              let base64 = ImageExporter.jpegBase64(from: drawing, canvasBounds: canvasBounds) else {
            phase = .failed("画布是空的，请先绘制流程图")
            return
        }
        let apiKey = KeychainHelper.loadAPIKey() ?? ""
        let imageData = Data(base64Encoded: base64) ?? Data()

        responseText = ""
        phase = .streaming

        task = Task {
            do {
                let stream = ZenMux.streamCompletion(
                    apiKey: apiKey,
                    model: model,
                    systemPrompt: Prompts.system,
                    userText: Prompts.userText(language: language),
                    imageBase64JPEG: base64)
                for try await chunk in stream {
                    responseText += chunk
                }
                phase = .finished
                if !responseText.isEmpty {
                    let record = GenerationRecord(
                        modelName: model,
                        language: language.rawValue,
                        imageData: imageData,
                        responseText: responseText)
                    modelContext.insert(record)
                }
            } catch is CancellationError {
                phase = .finished
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if phase == .streaming { phase = .finished }
    }
}
```

### 4.2 `Views/CanvasView.swift` —— PencilKit 包装 【逐字复制】

```swift
import SwiftUI
import PencilKit

struct PencilCanvas: UIViewRepresentable {
    let canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
```

### 4.3 `Views/ContentView.swift` —— 整体替换阶段 1 的占位（引导实现，非逐字）

**必须满足的接口约束：**

- 持有：`@State private var canvasView = PKCanvasView()`、`@StateObject private var viewModel = GenerationViewModel()`、`@State private var language: CodeLanguage = .python`、`@EnvironmentObject var settings: AppSettings`、`@Environment(\.modelContext) private var modelContext`。
- 用 `@Environment(\.horizontalSizeClass)` 判断布局：
  - `.regular`（iPad 横屏）：`HStack` 左侧画布区、右侧 `ResultView`，各占约一半（`frame(maxWidth: .infinity)`）。
  - `.compact`：`TabView`，Tab 1 = 画布，Tab 2 = 结果；点生成后用 `@State var selectedTab` 自动切到结果 Tab。
- 画布区 = 工具条 + `PencilCanvas(canvasView: canvasView)`。工具条控件从左到右：
  1. 笔按钮：`canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)`
  2. 橡皮按钮：`canvasView.tool = PKEraserTool(.vector)`
  3. 撤销：`canvasView.undoManager?.undo()`；重做：`canvasView.undoManager?.redo()`
  4. 清空按钮：弹 `confirmationDialog` 确认后 `canvasView.drawing = PKDrawing()`
  5. `Picker`（segmented 样式）绑定 `language`，两个选项 Python / Swift
  6. `Menu` 显示 `settings.selectedModel`，列出 `settings.models` 供切换
  7. 生成按钮：`viewModel.isStreaming` 时显示「停止」（红色，调 `viewModel.stop()`），否则显示「生成代码」，调：
     `viewModel.generate(drawing: canvasView.drawing, canvasBounds: canvasView.bounds, language: language, model: settings.selectedModel, modelContext: modelContext)`
- 外层包 `NavigationStack`，toolbar 放「历史」（`clock` 图标）和「设置」（`gearshape` 图标）两个入口。阶段 3 时这两个按钮先用 `Text("TODO")` 的 sheet 占位，阶段 5/6 接入真实页面。
- `viewModel.needsAPIKey == true` 时弹 alert：「尚未设置 API Key，请前往设置页填写」，按钮打开设置 sheet；同时把 `needsAPIKey` 置回 false。
- 阶段 3 时 `ResultView` 尚不存在：先在结果位置放 `ScrollView { Text(viewModel.responseText) }` 占位，阶段 4 替换。

### 4.4 阶段 3 验收清单

- [ ] 工具条 7 组控件齐全，行为与上述约束一致
- [ ] 空画布点「生成」→ `phase == .failed("画布是空的，请先绘制流程图")`，不发网络请求
- [ ] 无 API Key 点「生成」→ 弹 alert 引导设置，不发网络请求
- [ ] iPad 横屏为左右分栏；紧凑宽度为 Tab
- [ ] 阶段门禁命令输出 `BUILD SUCCEEDED`（粘贴输出）
- [ ] git commit：`Phase 3: 画布与主布局`

---

## 5. 阶段 4：结果页（流式渲染 / 高亮 / 拷贝）

### 5.1 `Views/ResultView.swift`（引导实现，非逐字）

**必须满足的接口约束：**

- 入参：`@ObservedObject var viewModel: GenerationViewModel`。
- 主体 `ScrollView`，内容 = `ResponseParser.parse(viewModel.responseText)` 的段落列表（`ForEach`，用 Segment 的 `id`）：
  - `.text` 段：`Text(LocalizedStringKey(content))`（LocalizedStringKey 可渲染基本 Markdown 粗体等），正常字体。
  - `.code` 段：深色圆角卡片（背景 `Color(white: 0.15)`，圆角 12），内容 `Text(SyntaxHighlighter.highlight(content, language: language))`，等宽字体 `.font(.system(.callout, design: .monospaced))`，横向可滚动（`ScrollView(.horizontal)`）。
  - 代码卡片右上角「拷贝」按钮：`UIPasteboard.general.string = content`，点击后按钮图标变为 `checkmark`（绿色）2 秒后恢复（用 `Task { try? await Task.sleep(...) }` 实现，不引入 Timer）。
- 状态显示：
  - `phase == .idle` 且无文本：居中占位提示「在左侧画好流程图后，点击『生成代码』」。
  - `phase == .streaming`：顶部显示 `ProgressView()` + 「正在生成…」。
  - `phase == .failed(let msg)`：红色错误横幅显示 msg。
- 流式期间自动滚动到底部：用 `ScrollViewReader` + 在 `viewModel.responseText` 变化时 `scrollTo` 底部锚点。

### 5.2 阶段 4 验收清单

- [ ] 文字/代码段交替渲染，代码有高亮和等宽字体
- [ ] 拷贝按钮工作且有打勾反馈
- [ ] 三种状态（空闲占位 / 生成中 / 失败横幅）都有对应 UI
- [ ] ContentView 中的占位 ScrollView 已替换为 ResultView
- [ ] 阶段门禁命令输出 `BUILD SUCCEEDED`（粘贴输出）
- [ ] git commit：`Phase 4: 结果页`

---

## 6. 阶段 5：设置页

### 6.1 `Views/SettingsView.swift`（引导实现，非逐字）

**必须满足的接口约束：**

- `Form` 三个 Section：

**Section 1「API Key」**
- 已保存 Key（`KeychainHelper.loadAPIKey()` 非空）时：显示掩码文本 —— 格式为前缀 `sk-****` + Key 的最后 4 位；**绝不显示完整 Key，绝不把明文回填进输入框**。旁边「删除」按钮（红色，需 `confirmationDialog` 确认，确认后调 `KeychainHelper.deleteAPIKey()`）。
- 未保存 Key 时：`SecureField("输入 ZenMux API Key", text: $keyInput)` + 「保存」按钮。
- 保存前预检【防呆】：`trimmingCharacters(in: .whitespacesAndNewlines)` 后必须非空且长度 ≥ 20，否则弹 alert「API Key 格式不正确」并拒绝保存。
- 未保存 Key 时，Section 顶部显示引导卡片：文案「还没有 API Key？前往 ZenMux 注册获取」+ `Link("获取 API Key", destination: URL(string: AppSettings.inviteURL)!)`。

**Section 2「模型管理」**
- `List` 列出 `settings.models`，当前 `settings.selectedModel` 行尾显示 `checkmark`；点击行 = 选中该模型。
- 左滑删除：调 `settings.removeModel(at:)`。**当 `settings.models.count == 1` 时禁用删除**（`.deleteDisabled(settings.models.count == 1)`）。
- 底部「添加模型」：TextField 输入模型 ID + 添加按钮，调 `settings.addModel(_:)`；返回 false 时弹 alert「模型名为空或已存在」。

**Section 3「关于」**
- 只读展示 Base URL：`Text(AppSettings.baseURL)`（灰色，不可编辑——**不提供任何修改 Base URL 的 UI**）。

- 该页面以 sheet 形式从 ContentView 的设置按钮弹出（替换阶段 3 的 TODO 占位）。

### 6.2 阶段 5 验收清单

- [ ] Key 保存后 UI 只显示掩码（`sk-****` + 尾 4 位），无任何途径看到完整 Key
- [ ] 短于 20 字符或空白的 Key 被拒绝保存
- [ ] 无 Key 时显示邀请链接卡片，链接可点击打开 `https://zenmux.ai/invite/GBQMC5`
- [ ] 模型可添加（空白/重复被拒）、可左滑删除、只剩 1 个时删除被禁用
- [ ] 删除当前选中模型后自动选中列表第一项
- [ ] 杀掉 App 重启后 Key 与模型列表仍在（Keychain / UserDefaults 持久化）
- [ ] Base URL 无任何修改入口
- [ ] 阶段门禁命令输出 `BUILD SUCCEEDED`（粘贴输出）
- [ ] git commit：`Phase 5: 设置页`

---

## 7. 阶段 6：历史记录 + 收尾

### 7.1 `Views/HistoryView.swift`（引导实现，非逐字）

**必须满足的接口约束：**

- `@Query(sort: \GenerationRecord.createdAt, order: .reverse) private var records: [GenerationRecord]`
- 列表行：左侧缩略图（`UIImage(data: record.imageData)` 转 `Image`，`60x60`，圆角，`scaledToFill` + clipped），右侧两行 —— 第一行 `createdAt` 格式化日期，第二行「模型名 · 语言」灰色小字。
- 点击行 → push 详情页：上方原图（可缩放不强制），下方复用与 ResultView 相同的段落渲染逻辑展示 `record.responseText`（含高亮与拷贝按钮）。做法：把 ResultView 中的段落渲染部分抽成一个接受 `String` 的子视图，两处共用；**不允许复制粘贴两份渲染代码**。
- 左滑删除记录：`modelContext.delete(record)`。
- 空状态：居中提示「还没有历史记录」。
- 该页面从 ContentView 的历史按钮进入（替换阶段 3 的 TODO 占位）。

### 7.2 收尾

- 全局检查：无编译警告级别的死代码；阶段 3 的所有 TODO 占位均已替换。
- 运行最终验收（8 节）。

### 7.3 阶段 6 验收清单

- [ ] 历史列表显示缩略图 + 时间 + 模型/语言，倒序排列
- [ ] 详情页复用同一份段落渲染子视图（代码里只有一份实现）
- [ ] 可左滑删除；空状态有提示
- [ ] 阶段门禁命令输出 `BUILD SUCCEEDED`（粘贴输出）
- [ ] git commit：`Phase 6: 历史与收尾`

---

## 8. 最终验收清单（人工在真机/模拟器执行）

| # | 操作 | 期望结果 |
|---|---|---|
| 1 | 全新安装启动 | 主界面正常，模型列表含两个默认模型 |
| 2 | 无 Key 点「生成」 | alert 引导去设置页，无网络请求 |
| 3 | 设置页点邀请链接 | Safari 打开 `https://zenmux.ai/invite/GBQMC5` |
| 4 | 输入合法 Key 保存，重启 App | 设置页显示掩码 `sk-****XXXX`，Key 仍在 |
| 5 | 空画布点「生成」 | 提示「画布是空的」，无网络请求 |
| 6 | 画一个简单流程图（如：开始→输入n→判断n>0→输出→结束），选 Python，点生成 | 流式出现理解说明 + ```python 代码块（有高亮）+ 逐步解释 |
| 7 | 点代码卡片「拷贝」 | 剪贴板为纯代码文本，按钮打勾 2 秒 |
| 8 | 生成中点「停止」 | 流式立即停止，已有内容保留 |
| 9 | 同一张图切 Swift 再生成 | 得到 ```swift 代码块，高亮为 Swift 规则 |
| 10 | 打开历史 | 两条记录（Python/Swift 各一），缩略图正确，详情可看可拷贝 |
| 11 | 设置页添加模型 `test/model` 再删除 | 添加成功、删除成功；删到只剩 1 个时删除禁用 |
| 12 | 故意把 Key 改错再生成 | 显示「API Key 无效…（HTTP 401）」错误横幅，App 不崩溃 |
| 13 | iPhone 模拟器运行 | Tab 布局可用，生成后自动切到结果 Tab |

全部通过 → 项目完成。任何一项不通过 → 按 0.4 失败协议处理。
