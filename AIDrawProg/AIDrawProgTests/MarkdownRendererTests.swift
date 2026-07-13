import Testing
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
}
