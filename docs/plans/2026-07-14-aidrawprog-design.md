# AIDrawProg 设计文档（2026-07-14）

手绘流程图转代码的 iOS 学习工具。学生用手指或 Apple Pencil 绘制流程图/示意图，AI 理解后生成 Python 或 Swift 代码，带语法高亮、逐步解释与一键拷贝。

本设计已与需求方逐项确认，最终产出物为 `SPEC.md`（交由低级 AI 执行，含防呆机制）。

## 已确认的关键决策

| 决策点 | 结论 |
|---|---|
| 设备定位 | iPad 优先（横屏左画布右结果），兼容 iPhone（Tab 切换） |
| 部署目标 | 保持工程默认 iOS 26.5，不修改工程配置 |
| 识别方案 | 画布截图（白底 JPEG，最长边 ≤1568px）直接发视觉模型 |
| 结果呈现 | SSE 流式输出；内容 = 图的理解说明 + 代码块 + 逐步解释（中文，面向学生） |
| 语法高亮 | 自写纯 Swift 正则高亮（零第三方依赖），支持 Python/Swift |
| 历史记录 | SwiftData 保存（缩略图 + 回答 + 时间 + 模型），可查看/删除 |
| 语言选择 | 生成前分段控件选 Python/Swift，单语言输出 |
| AI 平台 | ZenMux，Base URL 固定 `https://zenmux.ai/api/v1`，OpenAI 兼容 chat/completions |
| 默认模型 | `anthropic/claude-sonnet-4.6`、`openai/gpt-5.4`，设置页可增删（不可删空） |
| API Key | Keychain 永久保存；UI 掩码显示（SecureField 输入，已存 Key 只显尾 4 位）；无 Key 时引导至邀请链接 https://zenmux.ai/invite/GBQMC5 |
| SPEC 粒度 | 高风险件（Keychain/SSE 客户端/高亮器/围栏解析/图像导出/编排 ViewModel/Prompt）给全文逐字照抄；UI 给接口约束 + 验收清单 |

## 架构

技术栈：SwiftUI + PencilKit + SwiftData + URLSession，零第三方依赖。
Xcode 26 filesystem-synchronized groups：新增 .swift 文件自动入编译目标，无需改 pbxproj。

```
AIDrawProg/AIDrawProg/AIDrawProg/   （源码目录）
├── AIDrawProgApp.swift        入口（改造模板，schema 换成 GenerationRecord）
├── Models/GenerationRecord.swift、AppSettings.swift
├── Services/KeychainHelper.swift、ZenMuxClient.swift、ResponseParser.swift、
│            SyntaxHighlighter.swift、ImageExporter.swift、Prompts.swift、
│            GenerationViewModel.swift
└── Views/ContentView.swift、CanvasView.swift、ResultView.swift、
         HistoryView.swift、SettingsView.swift
```

数据流：PKCanvasView.drawing → ImageExporter（白底 JPEG base64）→ ZenMuxClient（SSE 流式）→ GenerationViewModel 累积 → ResponseParser 切分文字/代码段 → ResultView 渲染（SyntaxHighlighter 高亮 + 拷贝）→ 完成后存 SwiftData。

## 防呆机制（SPEC 执行框架）

1. **硬性禁令清单**：禁加依赖、禁改 pbxproj/部署目标/签名、禁改「逐字复制」代码、禁引入 SPEC 未提及的框架、不确定即停。
2. **关键代码全文照抄**：9 个高风险源文件在 SPEC 中给出完整可编译代码。
3. **阶段门禁**：6 个串行阶段，每阶段结尾必须执行 xcodebuild 并粘贴输出，见 `BUILD SUCCEEDED` 才准进入下一阶段；禁止全部写完再统一编译。
4. **可勾选验收清单**：每阶段附行为级 checklist，逐项自查。
5. **失败协议**：同一编译错误修 3 次不过 → 停止、原样粘贴错误、上报人类；禁止注释代码或删功能来「让编译通过」。

## 用户侧防呆

- 空画布点生成 → 本地拦截提示，不发请求。
- 无 API Key 点生成 → 弹出引导（含邀请链接），不发请求。
- API Key 保存前预检（去空白、非空、长度 ≥20）。
- 模型列表不可删空（剩 1 个时禁用删除）；删除选中模型自动回落第一项。
- Base URL 不提供 UI 修改。
- HTTP 401/429/其它错误映射为中文人话提示；请求可取消；60s 超时。
- 模型答复「图不可辨认」时按 prompt 约定引导学生重画，不编造代码。
