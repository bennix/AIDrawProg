import Testing
import Foundation
import CoreGraphics
@testable import AIDrawProg

struct MarkdownRendererTests {
    @Test func parsesHeadingAndPipeTableIntoDisplayBlocks() {
        let blocks = MarkdownRenderer.parse("""
        # 标题

        | 名称 | 值 |
        | --- | --- |
        | Python | 3 |
        """)

        #expect(blocks == [
            .heading(level: 1, content: "标题"),
            .table(headers: ["名称", "值"], rows: [["Python", "3"]]),
        ])
    }

    @Test func appendsQuestionWithAnAnswerPlaceholderToTranscript() {
        let transcript = FollowUpTranscript.appending(
            question: "为什么这里要用循环？",
            to: "这是初始回答。")

        #expect(transcript == """
        这是初始回答。

        ---

        ## 追问

        **问题：** 为什么这里要用循环？

        **回答：**
        """)
    }

    @Test func parsesHorizontalRuleAsDivider() {
        #expect(MarkdownRenderer.parse("前文\n\n---\n\n后文") == [
            .paragraph("前文"),
            .divider,
            .paragraph("后文"),
        ])
    }

    @Test @MainActor func clearingGenerationResetsDisplayedResponse() {
        let viewModel = GenerationViewModel()
        viewModel.responseText = "已生成的代码"
        viewModel.phase = .finished

        viewModel.clearGeneration()

        #expect(viewModel.responseText.isEmpty)
        #expect(viewModel.phase == .idle)
    }

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
}
