import Foundation

enum MarkdownRenderer {
    enum Block: Equatable {
        case heading(level: Int, content: String)
        case paragraph(String)
        case table(headers: [String], rows: [[String]])
        case divider
    }

    static func parse(_ markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [Block] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            if isHorizontalRule(line) {
                blocks.append(.divider)
                index += 1
                continue
            }

            if let heading = heading(from: line) {
                blocks.append(heading)
                index += 1
                continue
            }

            if index + 1 < lines.count,
               isTableRow(line),
               isTableSeparator(lines[index + 1]) {
                let headers = tableCells(in: line)
                var rows: [[String]] = []
                index += 2
                while index < lines.count, isTableRow(lines[index]) {
                    let cells = tableCells(in: lines[index])
                    guard !cells.isEmpty else { break }
                    rows.append(Array(cells.prefix(headers.count)))
                    index += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }

            var paragraphLines = [line]
            index += 1
            while index < lines.count {
                let next = lines[index]
                if next.trimmingCharacters(in: .whitespaces).isEmpty ||
                    heading(from: next) != nil ||
                    (index + 1 < lines.count && isTableRow(next) && isTableSeparator(lines[index + 1])) {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
        }

        return blocks
    }

    private static func heading(from line: String) -> Block? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let content = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return nil }
        return .heading(level: level, content: content)
    }

    private static func isTableRow(_ line: String) -> Bool {
        tableCells(in: line).count > 1
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.allSatisfy { $0 == "-" }
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(in: line)
        return !cells.isEmpty && cells.allSatisfy { cell in
            let core = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return core.count >= 3 && core.allSatisfy { $0 == "-" }
        }
    }

    private static func tableCells(in line: String) -> [String] {
        var cells = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }
}
