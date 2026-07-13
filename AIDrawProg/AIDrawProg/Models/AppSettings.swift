import Foundation
import Combine
import SwiftUI

/// 模型列表与当前选中模型（UserDefaults 持久化）。
/// API Key 不在此处 —— 见 KeychainHelper。
final class AppSettings: ObservableObject {
    static let defaultModels = ["anthropic/claude-sonnet-4.6", "openai/gpt-5.4"]
    static let baseURL = "https://zenmux.ai/api/v1"
    static let inviteURL = "https://zenmux.ai/invite/GBQMC5"

    private let modelsKey = "zenmux_models"
    private let selectedKey = "zenmux_selected_model"

    @Published var models: [String] {
        didSet { UserDefaults.standard.set(models, forKey: modelsKey) }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: selectedKey) }
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: modelsKey)
        let models = (saved?.isEmpty == false) ? saved! : Self.defaultModels
        self.models = models
        let savedSelected = UserDefaults.standard.string(forKey: selectedKey)
        self.selectedModel = (savedSelected.flatMap { models.contains($0) ? $0 : nil }) ?? models[0]
    }

    /// 添加模型。返回 false 表示被拒绝（空白或重复）。
    @discardableResult
    func addModel(_ raw: String) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !models.contains(name) else { return false }
        models.append(name)
        return true
    }

    /// 删除模型。防呆：至少保留 1 个；删除当前选中项时回落到第一项。
    func removeModel(at offsets: IndexSet) {
        guard models.count > 1 else { return }
        let removed = offsets.map { models[$0] }
        models.remove(atOffsets: offsets)
        if removed.contains(selectedModel) {
            selectedModel = models[0]
        }
    }
}
