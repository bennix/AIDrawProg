import SwiftUI

enum SyntaxHighlighter {
    private static let pythonKeywords =
        "def|return|if|elif|else|for|while|in|not|and|or|import|from|as|class|try|except|finally|with|pass|break|continue|lambda|None|True|False|print|range|len|input|int|str|float|list|dict"
    private static let swiftKeywords =
        "func|return|if|else|for|while|in|var|let|class|struct|enum|import|guard|switch|case|default|break|continue|nil|true|false|print|String|Int|Double|Bool|Array|Dictionary|self|init|throws|try|catch|do"

    static func highlight(_ code: String, language: CodeLanguage?) -> AttributedString {
        var attributed = AttributedString(code)
        attributed.foregroundColor = Color(white: 0.9)

        let keywords = (language == .swift) ? swiftKeywords : pythonKeywords
        let commentPattern = (language == .swift) ? "//[^\\n]*" : "#[^\\n]*"

        // 顺序重要：后面的规则会覆盖前面的着色
        let rules: [(pattern: String, color: Color)] = [
            ("\\b\\d+(\\.\\d+)?\\b", .orange),
            ("\\b(\(keywords))\\b", Color(red: 1.0, green: 0.5, blue: 0.7)),
            ("\"[^\"\\n]*\"", Color(red: 1.0, green: 0.8, blue: 0.4)),
            ("'[^'\\n]*'", Color(red: 1.0, green: 0.8, blue: 0.4)),
            (commentPattern, Color(red: 0.5, green: 0.75, blue: 0.5)),
        ]

        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            let fullRange = NSRange(code.startIndex..., in: code)
            for match in regex.matches(in: code, range: fullRange) {
                guard let stringRange = Range(match.range, in: code),
                      let attrRange = Range(stringRange, in: attributed) else { continue }
                attributed[attrRange].foregroundColor = rule.color
            }
        }
        return attributed
    }
}
