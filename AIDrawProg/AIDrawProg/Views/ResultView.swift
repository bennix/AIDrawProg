import SwiftUI
import UIKit

struct ResultView: View {
    @ObservedObject var viewModel: GenerationViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    status
                    if !viewModel.responseText.isEmpty {
                        ResponseSegmentsView(responseText: viewModel.responseText)
                        FollowUpComposer(viewModel: viewModel)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("result-bottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .onChange(of: viewModel.responseText) { _, _ in
                withAnimation {
                    proxy.scrollTo("result-bottom", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch viewModel.phase {
        case .idle where viewModel.responseText.isEmpty:
            ContentUnavailableView(
                "在左侧画好流程图后，点击『生成代码』",
                systemImage: "pencil.and.scribble")
                .frame(maxWidth: .infinity, minHeight: 250)
        case .streaming:
            HStack {
                ProgressView()
                Text("正在生成…")
            }
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        default:
            EmptyView()
        }
    }
}

struct FollowUpComposer: View {
    @ObservedObject var viewModel: GenerationViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var question = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("继续追问…", text: $question, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Button {
                viewModel.followUp(question, model: settings.selectedModel)
                question = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
        }
        .padding(.top, 4)
    }
}

struct ResponseSegmentsView: View {
    let responseText: String

    var body: some View {
        ForEach(ResponseParser.parse(responseText)) { segment in
            switch segment {
            case .text(_, let content):
                MarkdownTextView(markdown: content)
            case .code(_, let content, let language):
                CodeBlockView(content: content, language: language)
            }
        }
    }
}

private struct CodeBlockView: View {
    let content: String
    let language: CodeLanguage?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button {
                UIPasteboard.general.string = content
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                Label("拷贝", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .white)
            }
            ScrollView(.horizontal) {
                Text(SyntaxHighlighter.highlight(content, language: language))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}
