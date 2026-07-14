import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GenerationRecord.createdAt, order: .reverse) private var records: [GenerationRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView("还没有历史记录", systemImage: "clock")
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink {
                            HistoryDetailView(record: record)
                        } label: {
                            HStack(spacing: 12) {
                                thumbnail(for: record)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.createdAt, format: .dateTime.year().month().day().hour().minute())
                                    Text("\(record.modelName) · \(record.language)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
        .navigationTitle("历史")
    }

    @ViewBuilder
    private func thumbnail(for record: GenerationRecord) -> some View {
        if let image = UIImage(data: record.imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.15))
                .frame(width: 60, height: 60)
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

private struct HistoryDetailView: View {
    let record: GenerationRecord
    @StateObject private var viewModel = GenerationViewModel()
    @State private var graph: FlowchartGraph?
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = UIImage(data: record.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if graph != nil {
                    Button("编辑流程图") { showingEditor = true }
                        .buttonStyle(.borderedProminent)
                }
                ResponseSegmentsView(responseText: viewModel.responseText)
                FollowUpComposer(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("生成详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load(record: record)
            graph = record.flowchartData.flatMap { try? JSONDecoder().decode(FlowchartGraph.self, from: $0) }
        }
        .sheet(isPresented: $showingEditor) {
            FlowchartEditorView(
                graph: Binding(
                    get: { graph ?? FlowchartGraph(nodes: [], edges: []) },
                    set: { graph = $0 }),
                restoreOriginal: { graph = nil },
                save: {
                    if let graph {
                        viewModel.saveGraph(graph, to: record)
                    }
                })
        }
    }
}
