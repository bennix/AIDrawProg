import SwiftUI
import SwiftData
import PencilKit

struct ContentView: View {
    @State private var canvasView = PKCanvasView()
    @StateObject private var viewModel = GenerationViewModel()
    @State private var language: CodeLanguage = .python
    @State private var selectedTab = 0
    @State private var showingClearConfirmation = false
    @AppStorage("autoSnapShapes") private var autoSnapShapes = true
    @State private var showingSettings = false
    @State private var showingHistory = false
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        canvasSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Divider()
                        ResultView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        canvasSection
                            .tabItem { Label("画布", systemImage: "pencil.and.scribble") }
                            .tag(0)
                        ResultView(viewModel: viewModel)
                            .tabItem { Label("结果", systemImage: "doc.text") }
                            .tag(1)
                    }
                }
            }
            .navigationTitle("AIDrawProg")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingHistory = true } label: {
                        Label("历史", systemImage: "clock")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingHistory) {
                NavigationStack { HistoryView() }
            }
            .alert("尚未设置 API Key，请前往设置页填写", isPresented: $viewModel.needsAPIKey) {
                Button("前往设置") { showingSettings = true }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var canvasSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button { canvasView.tool = PKInkingTool(.pen, color: .black, width: 5) } label: {
                        Label("笔", systemImage: "pencil")
                    }
                    Button { canvasView.tool = PKEraserTool(.vector) } label: {
                        Label("橡皮", systemImage: "eraser")
                    }
                    Button { canvasView.undoManager?.undo() } label: {
                        Label("撤销", systemImage: "arrow.uturn.backward")
                    }
                    Button { canvasView.undoManager?.redo() } label: {
                        Label("重做", systemImage: "arrow.uturn.forward")
                    }
                    Button(role: .destructive) { showingClearConfirmation = true } label: {
                        Label("清空", systemImage: "trash")
                    }
                    Toggle(isOn: $autoSnapShapes) {
                        Label("规整", systemImage: "square.on.circle")
                    }
                    .toggleStyle(.button)
                    Picker("语言", selection: $language) {
                        Text("Python").tag(CodeLanguage.python)
                        Text("Swift").tag(CodeLanguage.swift)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    Menu {
                        ForEach(settings.models, id: \.self) { model in
                            Button(model) { settings.selectedModel = model }
                        }
                    } label: {
                        Label(settings.selectedModel, systemImage: "cpu")
                    }
                    Button {
                        if viewModel.isStreaming {
                            viewModel.stop()
                        } else {
                            viewModel.generate(
                                drawing: canvasView.drawing,
                                canvasBounds: canvasView.bounds,
                                graph: nil,
                                language: language,
                                model: settings.selectedModel,
                                modelContext: modelContext)
                            if horizontalSizeClass != .regular { selectedTab = 1 }
                        }
                    } label: {
                        Label(viewModel.isStreaming ? "停止" : "生成代码",
                              systemImage: viewModel.isStreaming ? "stop.fill" : "sparkles")
                    }
                    .tint(viewModel.isStreaming ? .red : .accentColor)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            Divider()
            if viewModel.isInspectionVisible {
                InspectionHintView(messages: viewModel.inspection.messages) {
                    viewModel.dismissInspection()
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            PencilCanvas(canvasView: canvasView, autoSnapEnabled: autoSnapShapes)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
        }
        .confirmationDialog("确定要清空画布吗？", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                canvasView.drawing = PKDrawing()
                viewModel.clearGeneration()
            }
        }
    }

}
