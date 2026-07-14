import Testing
import Foundation
import CoreGraphics
import UIKit
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

    @Test func classifiesAxisAlignedQuadrilateralAsProcess() {
        #expect(FlowchartRecognizer.classify(points: [
            .init(0, 0), .init(100, 0), .init(100, 50), .init(0, 50), .init(0, 0),
        ]) == .process)
    }

    @Test func classifiesRotatedQuadrilateralAsDecision() {
        #expect(FlowchartRecognizer.classify(points: [
            .init(50, 0), .init(100, 50), .init(50, 100), .init(0, 50), .init(50, 0),
        ]) == .decision)
    }

    @Test func snapsArrowToNearestNodes() {
        let source = FlowchartNode(kind: .process, frame: .init(x: 0.1, y: 0.1, width: 0.2, height: 0.1))
        let target = FlowchartNode(kind: .process, frame: .init(x: 0.1, y: 0.8, width: 0.2, height: 0.1))
        let edge = FlowchartRecognizer.edge(
            start: .init(x: 120, y: 120), end: .init(x: 120, y: 520),
            nodes: [source, target], canvasSize: .init(width: 600, height: 600))

        #expect(edge?.sourceID == source.id)
        #expect(edge?.targetID == target.id)
    }

    @Test func rendererCreatesCanvasSizedImage() {
        let graph = FlowchartGraph(nodes: [.init(kind: .process, frame: .init(x: 0.1, y: 0.1, width: 0.3, height: 0.15))], edges: [])
        let image = FlowchartRenderer.image(graph: graph, size: .init(width: 600, height: 400))

        #expect(image.size == .init(width: 600, height: 400))
    }
}
