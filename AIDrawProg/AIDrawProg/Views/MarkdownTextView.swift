import SwiftUI

struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(MarkdownRenderer.parse(markdown).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    Text(LocalizedStringKey(content))
                        .font(font(for: level))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .paragraph(let content):
                    Text(LocalizedStringKey(content))
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .table(let headers, let rows):
                    MarkdownTableView(headers: headers, rows: rows)
                }
            }
        }
    }

    private func font(for level: Int) -> Font {
        switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        default: .headline
        }
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(headers.indices, id: \.self) { index in
                        cell(headers[index], isHeader: true)
                    }
                }
                ForEach(rows.indices, id: \.self) { rowIndex in
                    GridRow {
                        ForEach(headers.indices, id: \.self) { columnIndex in
                            cell(value(at: rowIndex, column: columnIndex), isHeader: false)
                        }
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.35)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func cell(_ content: String, isHeader: Bool) -> some View {
        Text(LocalizedStringKey(content))
            .font(isHeader ? .headline : .body)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHeader ? Color.secondary.opacity(0.12) : .clear)
            .overlay(Rectangle().stroke(.secondary.opacity(0.25)))
    }

    private func value(at row: Int, column: Int) -> String {
        guard rows[row].indices.contains(column) else { return "" }
        return rows[row][column]
    }
}
