import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var keyInput = ""
    @State private var newModel = ""
    @State private var hasSavedKey = KeychainHelper.loadAPIKey() != nil
    @State private var showingInvalidKeyAlert = false
    @State private var showingModelAlert = false
    @State private var showingDeleteKeyConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("API Key") {
                    if hasSavedKey {
                        HStack {
                            Text(maskedKey)
                            Spacer()
                            Button("删除", role: .destructive) {
                                showingDeleteKeyConfirmation = true
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("还没有 API Key？前往 ZenMux 注册获取")
                            Link("获取 API Key", destination: URL(string: AppSettings.inviteURL)!)
                        }
                        SecureField("输入 ZenMux API Key", text: $keyInput)
                        Button("保存") { saveKey() }
                    }
                }

                Section("模型管理") {
                    ForEach(settings.models, id: \.self) { model in
                        Button {
                            settings.selectedModel = model
                        } label: {
                            HStack {
                                Text(model)
                                Spacer()
                                if model == settings.selectedModel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete(perform: settings.removeModel)
                    .deleteDisabled(settings.models.count == 1)

                    HStack {
                        TextField("模型 ID", text: $newModel)
                        Button("添加") {
                            guard settings.addModel(newModel) else {
                                showingModelAlert = true
                                return
                            }
                            newModel = ""
                        }
                    }
                }

                Section("关于") {
                    Text(AppSettings.baseURL)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("API Key 格式不正确", isPresented: $showingInvalidKeyAlert) {
                Button("确定", role: .cancel) {}
            }
            .alert("模型名为空或已存在", isPresented: $showingModelAlert) {
                Button("确定", role: .cancel) {}
            }
            .confirmationDialog("确定要删除 API Key 吗？", isPresented: $showingDeleteKeyConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    KeychainHelper.deleteAPIKey()
                    hasSavedKey = false
                    keyInput = ""
                }
            }
        }
    }

    private var maskedKey: String {
        guard let key = KeychainHelper.loadAPIKey() else { return "" }
        return "sk-****\(key.suffix(4))"
    }

    private func saveKey() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 20 else {
            showingInvalidKeyAlert = true
            return
        }
        guard KeychainHelper.saveAPIKey(key) else { return }
        keyInput = ""
        hasSavedKey = true
    }
}
