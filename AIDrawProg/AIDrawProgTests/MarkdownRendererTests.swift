import Testing
import Foundation
import CoreGraphics
import UIKit
import PencilKit
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

    @Test func imageExportCropsToContentInsteadOfInfiniteCanvas() {
        let crop = ImageExporter.exportBounds(
            contentBounds: .init(x: 5_000, y: 6_000, width: 120, height: 80),
            canvasBounds: .init(x: 0, y: 0, width: 12_000, height: 12_000))

        #expect(crop != nil)
        #expect(crop!.width < 500)
        #expect(crop!.height < 500)
        #expect(crop!.contains(.init(x: 5_060, y: 6_040)))
    }

    @Test func rendererCreatesCanvasSizedImage() {
        let graph = FlowchartGraph(nodes: [.init(kind: .process, frame: .init(x: 0.1, y: 0.1, width: 0.3, height: 0.15))], edges: [])
        let image = FlowchartRenderer.image(graph: graph, size: .init(width: 600, height: 400))

        #expect(image.size == .init(width: 600, height: 400))
    }
}

struct ShapeSnapperTests {
    private func wobble(_ points: [CGPoint], amount: CGFloat = 3) -> [CGPoint] {
        points.enumerated().map { index, point in
            let offset = amount * sin(CGFloat(index) * 1.7)
            return CGPoint(x: point.x + offset, y: point.y - offset)
        }
    }

    private func polygonStroke(_ corners: [CGPoint]) -> [CGPoint] {
        var points: [CGPoint] = []
        for index in corners.indices {
            let start = corners[index]
            let end = corners[(index + 1) % corners.count]
            for step in 0..<20 {
                let t = CGFloat(step) / 20
                points.append(CGPoint(x: start.x + (end.x - start.x) * t,
                                      y: start.y + (end.y - start.y) * t))
            }
        }
        points.append(corners[0])
        return points
    }

    @Test func recognizesHandDrawnRectangle() {
        let points = wobble(polygonStroke([
            CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 100),
            CGPoint(x: 300, y: 200), CGPoint(x: 100, y: 200),
        ]))

        guard case .rectangle(let rect)? = ShapeSnapper.classify(points: points) else {
            Issue.record("矩形笔画未被识别")
            return
        }
        #expect(abs(rect.minX - 97) < 8)
        #expect(abs(rect.maxX - 303) < 8)
    }

    @Test func recognizesHandDrawnDiamond() {
        let points = wobble(polygonStroke([
            CGPoint(x: 200, y: 100), CGPoint(x: 320, y: 180),
            CGPoint(x: 200, y: 260), CGPoint(x: 80, y: 180),
        ]))

        guard case .diamond? = ShapeSnapper.classify(points: points) else {
            Issue.record("菱形笔画未被识别")
            return
        }
    }

    @Test func recognizesHandDrawnEllipse() {
        let points = wobble((0...80).map { step -> CGPoint in
            let t = CGFloat(step) / 80 * 2 * .pi
            return CGPoint(x: 200 + 90 * cos(t), y: 150 + 60 * sin(t))
        }, amount: 2)

        guard case .ellipse? = ShapeSnapper.classify(points: points) else {
            Issue.record("椭圆笔画未被识别")
            return
        }
    }

    @Test func recognizesStraightLineWithAxisSnap() {
        let points = wobble((0...30).map { CGPoint(x: 100 + CGFloat($0) * 8, y: 150 + CGFloat($0) * 0.2) }, amount: 1.5)

        guard case .line(let waypoints)? = ShapeSnapper.classify(points: points) else {
            Issue.record("直线笔画未被识别")
            return
        }
        #expect(waypoints.count == 2)
        #expect(abs(waypoints[0].y - waypoints[1].y) < 0.001)
    }

    @Test func keepsElbowBendWhenRecognizingBentArrow() {
        var points = (0...40).map { CGPoint(x: 100 + CGFloat($0) * 5, y: 150) }
        points.append(contentsOf: (1...30).map { CGPoint(x: 300, y: 150 + CGFloat($0) * 5) })
        points.append(contentsOf: [
            CGPoint(x: 288, y: 285), CGPoint(x: 294, y: 292),
            CGPoint(x: 300, y: 300),
            CGPoint(x: 306, y: 292), CGPoint(x: 312, y: 285),
        ])

        guard case .arrow(let waypoints)? = ShapeSnapper.classify(points: wobble(points, amount: 1)) else {
            Issue.record("弯折箭头未被识别")
            return
        }
        #expect(waypoints.count == 3)
        #expect(abs(waypoints[1].x - 300) < 6)
        #expect(abs(waypoints[1].y - 150) < 6)
        #expect(abs(waypoints[2].y - 300) < 6)
    }

    @Test func recognizesElbowLineWithoutArrowhead() {
        var points = (0...40).map { CGPoint(x: 100 + CGFloat($0) * 5, y: 150) }
        points.append(contentsOf: (1...30).map { CGPoint(x: 300, y: 150 + CGFloat($0) * 5) })

        guard case .line(let waypoints)? = ShapeSnapper.classify(points: wobble(points, amount: 1.5)) else {
            Issue.record("弯折连线未被识别")
            return
        }
        #expect(waypoints.count == 3)
    }

    @Test func leavesStandaloneArrowheadVUnsnapped() {
        var points = (0...12).map { CGPoint(x: 100 + CGFloat($0) * 2, y: 100 + CGFloat($0) * 2.5) }
        points.append(contentsOf: (1...12).map { CGPoint(x: 124 - CGFloat($0) * 2, y: 130 + CGFloat($0) * 2.5) })

        #expect(ShapeSnapper.classify(points: points) == nil)
    }

    @Test func recognizesSingleStrokeArrow() {
        var points = (0...40).map { CGPoint(x: 100 + CGFloat($0) * 5, y: 150) }
        points.append(contentsOf: [
            CGPoint(x: 285, y: 138), CGPoint(x: 292, y: 144),
            CGPoint(x: 300, y: 150),
            CGPoint(x: 292, y: 156), CGPoint(x: 285, y: 162),
        ])

        guard case .arrow? = ShapeSnapper.classify(points: wobble(points, amount: 1)) else {
            Issue.record("箭头笔画未被识别")
            return
        }
    }

    @Test func recognizesRectangleWithUnclosedEndGap() {
        var points = wobble(polygonStroke([
            CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 100),
            CGPoint(x: 300, y: 200), CGPoint(x: 100, y: 200),
        ]))
        points.removeLast(12)

        guard case .rectangle? = ShapeSnapper.classify(points: points) else {
            Issue.record("留有缺口的矩形笔画未被识别")
            return
        }
    }

    @Test func mergesSeparateArrowheadStrokeIntoLine() {
        let line = makeStroke((0...60).map { CGPoint(x: 100 + CGFloat($0) * 5, y: 150) })
        var headPoints = (0...10).map { CGPoint(x: 380 + CGFloat($0) * 2, y: 135 + CGFloat($0) * 1.5) }
        headPoints.append(contentsOf: (1...10).map { CGPoint(x: 400 - CGFloat($0) * 2, y: 150 + CGFloat($0) * 1.5) })
        let head = makeStroke(headPoints)

        let merge = ShapeSnapper.arrowheadMerge(headStroke: head, strokes: [line])

        #expect(merge?.lineIndex == 0)
    }

    @Test func ignoresArrowheadStrokeFarFromAnyLine() {
        let line = makeStroke((0...60).map { CGPoint(x: 100 + CGFloat($0) * 5, y: 150) })
        var headPoints = (0...10).map { CGPoint(x: 380 + CGFloat($0) * 2, y: 335 + CGFloat($0) * 1.5) }
        headPoints.append(contentsOf: (1...10).map { CGPoint(x: 400 - CGFloat($0) * 2, y: 350 + CGFloat($0) * 1.5) })
        let head = makeStroke(headPoints)

        #expect(ShapeSnapper.arrowheadMerge(headStroke: head, strokes: [line]) == nil)
    }

    private func makeStroke(_ points: [CGPoint]) -> PKStroke {
        let controlPoints = points.enumerated().map { index, location in
            PKStrokePoint(location: location, timeOffset: TimeInterval(index) * 0.01,
                          size: CGSize(width: 5, height: 5), opacity: 1, force: 1,
                          azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black),
                        path: PKStrokePath(controlPoints: controlPoints, creationDate: Date()))
    }

    @Test func leavesSmallHandwritingAlone() {
        let points = (0...30).map { step -> CGPoint in
            let t = CGFloat(step) / 30 * 2 * .pi
            return CGPoint(x: 200 + 12 * cos(t), y: 150 + 10 * sin(t))
        }

        #expect(ShapeSnapper.classify(points: points) == nil)
    }

    @Test func leavesScribbleAlone() {
        let points = (0...60).map { step -> CGPoint in
            CGPoint(x: 100 + CGFloat(step) * 3,
                    y: 150 + 40 * sin(CGFloat(step) * 0.9))
        }

        #expect(ShapeSnapper.classify(points: points) == nil)
    }
}
