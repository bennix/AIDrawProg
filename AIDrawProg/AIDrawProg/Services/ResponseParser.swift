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
