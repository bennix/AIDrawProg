# AIDrawProg

中文 | [English](#english)

一款面向编程初学者的 iOS 应用：在画布上手绘流程图或程序示意图，使用 AI 将其转换为 Python 或 Swift 代码，并获得逐步讲解。

## 功能

- PencilKit 画布，支持手指与 Apple Pencil 绘制
- 画笔、橡皮、撤销、重做与一键清空
- Python / Swift 目标语言选择
- ZenMux 流式生成：图形理解、可运行代码和中文讲解
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
- Pen, eraser, undo, redo, and clear controls
- Python and Swift output selection
- Streaming ZenMux responses: diagram understanding, runnable code, and Chinese explanations
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
