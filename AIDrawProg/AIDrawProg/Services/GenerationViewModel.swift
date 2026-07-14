import SwiftUI
import PencilKit
import SwiftData
import Combine

@MainActor
final class GenerationViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case streaming
        case finished
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var responseText: String = ""
    @Published var needsAPIKey = false

    private var task: Task<Void, Never>?
    private var activeRecord: GenerationRecord?

    var isStreaming: Bool { phase == .streaming }

    func generate(drawing: PKDrawing, canvasBounds: CGRect,
                  language: CodeLanguage, model: String,
                  modelContext: ModelContext) {
        guard !isStreaming else { return }
        guard KeychainHelper.loadAPIKey() != nil else {
            needsAPIKey = true
            return
        }
        guard !drawing.strokes.isEmpty,
              let base64 = ImageExporter.jpegBase64(from: drawing, canvasBounds: canvasBounds) else {
            phase = .failed("画布是空的，请先绘制流程图")
            return
        }
        let apiKey = KeychainHelper.loadAPIKey() ?? ""
        let imageData = Data(base64Encoded: base64) ?? Data()

        responseText = ""
        phase = .streaming
        activeRecord = nil

        task = Task {
            do {
                let stream = ZenMux.streamCompletion(
                    apiKey: apiKey,
                    model: model,
                    systemPrompt: Prompts.system,
                    userText: Prompts.userText(language: language),
                    imageBase64JPEG: base64)
                for try await chunk in stream {
                    responseText += chunk
                }
                phase = .finished
                if !responseText.isEmpty {
                    let record = GenerationRecord(
                        modelName: model,
                        language: language.rawValue,
                        imageData: imageData,
                        responseText: responseText)
                    modelContext.insert(record)
                    activeRecord = record
                }
            } catch is CancellationError {
                phase = .finished
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if phase == .streaming { phase = .finished }
    }

    func clearGeneration() {
        task?.cancel()
        task = nil
        responseText = ""
        activeRecord = nil
        phase = .idle
    }

    func load(record: GenerationRecord) {
        task?.cancel()
        responseText = record.responseText
        activeRecord = record
        phase = .finished
    }

    func followUp(_ rawQuestion: String, model: String) {
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isStreaming, !question.isEmpty, !responseText.isEmpty else { return }
        guard let apiKey = KeychainHelper.loadAPIKey() else {
            needsAPIKey = true
            return
        }

        let previousResponse = responseText
        responseText = FollowUpTranscript.appending(question: question, to: previousResponse)
        phase = .streaming

        task = Task {
            do {
                let stream = ZenMux.streamFollowUp(
                    apiKey: apiKey,
                    model: model,
                    systemPrompt: Prompts.system,
                    previousResponse: previousResponse,
                    question: question)
                for try await chunk in stream {
                    responseText += chunk
                }
                phase = .finished
                activeRecord?.responseText = responseText
            } catch is CancellationError {
                phase = .finished
                activeRecord?.responseText = responseText
            } catch {
                phase = .failed(error.localizedDescription)
                activeRecord?.responseText = responseText
            }
        }
    }
}
