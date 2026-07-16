# AIDrawProg

中文 | [English](#english)

一款面向编程初学者的 iOS 应用：在画布上手绘流程图或程序示意图，使用 AI 将其转换为 Python 或 Swift 代码，并获得逐步讲解。

## 功能

- PencilKit 画布，支持手指与 Apple Pencil 绘制
- 大画布双指平移 / 捏合缩放，双指双击复位视口
- 画笔、橡皮、撤销、重做与一键清空
- 笔画自动规整：手绘矩形、菱形、椭圆、平行四边形、起止框，以及直线 / 弯折连线与箭头（含两笔箭头），落笔后原位替换为标准形状；工具栏「规整」开关可随时关闭，撤销可恢复手绘原稿
- Python / Swift 目标语言选择
- ZenMux 流式生成：图形理解、可运行代码和中文讲解
- 生成前的非阻断流程图结构提示，帮助学生检查未连接笔画和疑似误触标记
- Markdown 结果渲染，支持标题、表格、代码高亮与代码复制
- 对生成结果继续追问，追问内容会保存到历史记录
- SwiftData 本地历史记录：缩略图、详情、复制与删除
- API Key 使用 Keychain 保存，模型列表使用 UserDefaults 持久化
- iPad 横屏双栏布局；iPhone 紧凑宽度使用画布 / 结果标签页

## 环境要求

- Xcode 26 或更高版本
- iOS 26.5 SDK
- iPhone 或 iPad 模拟器 / 真机
- 可用的 ZenMux API Key

## 运行

1. 使用 Xcode 打开 `AIDrawProg/AIDrawProg.xcodeproj`。
2. 选择目标设备并运行。
3. 打开应用内“设置”，输入并保存 ZenMux API Key。
4. 在画布绘制流程图，选择语言和模型后点击“生成代码”。

ZenMux 注册与 API Key 获取入口：<https://zenmux.ai/invite/GBQMC5>

## 构建验证

```bash
cd AIDrawProg
xcodebuild -project AIDrawProg.xcodeproj -scheme AIDrawProg \
  -destination 'generic/platform=iOS Simulator' build
```

## 隐私

- API Key 仅保存于设备 Keychain，不会显示明文。
- 手绘图仅在请求生成或追问时发送至 ZenMux 服务。
- 生成记录存储在本机，可随时在历史页删除。

## English

AIDrawProg is an iOS app for programming beginners. Draw a flowchart or program sketch on a canvas, then use AI to turn it into Python or Swift code with a step-by-step explanation.

## Features

- PencilKit canvas with finger and Apple Pencil input
- Large workspace with two-finger pan/pinch zoom; double two-finger tap resets the viewport
- Pen, eraser, undo, redo, and clear controls
- Auto shape snap: hand-drawn rectangles, diamonds, ellipses, parallelograms, terminators, straight/elbow connectors, and arrows (including two-stroke arrowheads) are replaced in place with clean shapes; toggle Snap in the toolbar, and undo restores the original stroke
- Python and Swift output selection
- Streaming ZenMux responses: diagram understanding, runnable code, and Chinese explanations
- Non-blocking pre-generation flowchart hints for disconnected marks and likely accidental strokes
- Markdown rendering with headings, tables, syntax-highlighted code, and copy support
- Follow-up questions for generated answers; the conversation is saved in history
- Local SwiftData history with thumbnails, detail views, copy, and deletion
- API keys are stored in Keychain; model choices persist in UserDefaults
- Split canvas/result layout on regular-width iPad and tabs on compact iPhone layouts

## Requirements

- Xcode 26 or later
- iOS 26.5 SDK
- An iPhone or iPad simulator/device
- A valid ZenMux API key

## Run

1. Open `AIDrawProg/AIDrawProg.xcodeproj` in Xcode.
2. Select a destination and run the app.
3. Open Settings and save a ZenMux API key.
4. Draw a flowchart, choose a language and model, then tap Generate Code.

## Privacy

- API keys are stored only in the device Keychain and are never displayed in full.
- Drawings are sent to ZenMux only when generating or continuing a question.
- Generation history is stored locally and can be deleted from the History screen.
