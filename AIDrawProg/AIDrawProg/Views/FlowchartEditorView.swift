import SwiftUI

struct FlowchartEditorView: View {
    @Binding var graph: FlowchartGraph
    let restoreOriginal: () -> Void
    let save: () -> Void
    @State private var selectedNodeID: UUID?
    @State private var selectedEdgeID: UUID?
    @State private var connectionSourceID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Group {
                    if geometry.size.width > 700 {
                        HStack(spacing: 0) {
                            editorCanvas(size: geometry.size)
                            Divider()
                            inspector
                                .frame(width: 260)
                        }
                    } else {
                        VStack(spacing: 0) {
                            editorCanvas(size: CGSize(width: geometry.size.width, height: geometry.size.height * 0.68))
                            Divider()
                            inspector
                        }
                    }
                }
            }
            .navigationTitle("编辑流程图")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("恢复原稿", role: .destructive) {
                        restoreOriginal()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("添加节点") {
                        ForEach(FlowchartNodeKind.allCases) { kind in
                            Button(kind.displayName) { addNode(kind) }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func editorCanvas(size: CGSize) -> some View {
        ZStack {
            Color.white
            Canvas { context, _ in
                for edge in graph.edges {
                    guard let source = graph.nodes.first(where: { $0.id == edge.sourceID }),
                          let target = graph.nodes.first(where: { $0.id == edge.targetID }) else { continue }
                    let start = nodeCenter(source, size: size)
                    let end = nodeCenter(target, size: size)
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(edge.id == selectedEdgeID ? .orange : .primary), lineWidth: 2)
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    var arrow = Path()
                    arrow.move(to: end)
                    arrow.addLine(to: CGPoint(x: end.x - 10 * cos(angle - .pi / 6), y: end.y - 10 * sin(angle - .pi / 6)))
                    arrow.move(to: end)
                    arrow.addLine(to: CGPoint(x: end.x - 10 * cos(angle + .pi / 6), y: end.y - 10 * sin(angle + .pi / 6)))
                    context.stroke(arrow, with: .color(edge.id == selectedEdgeID ? .orange : .primary), lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedEdgeID = nil }

            ForEach(graph.nodes) { node in
                FlowchartNodeView(node: node, selected: node.id == selectedNodeID,
                                  connecting: node.id == connectionSourceID)
                    .frame(width: node.frame.width * size.width, height: node.frame.height * size.height)
                    .position(nodeCenter(node, size: size))
                    .onTapGesture { select(node) }
                    .gesture(DragGesture().onEnded { value in
                        let x = node.frame.x + value.translation.width / size.width
                        let y = node.frame.y + value.translation.height / size.height
                        graph.moveNode(id: node.id, to: .init(x: x, y: y, width: node.frame.width, height: node.frame.height))
                    })
            }
        }
        .overlay(alignment: .bottomLeading) {
            if connectionSourceID != nil {
                Text("请选择要连接到的目标节点")
                    .font(.caption)
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
                    .accessibilityLabel("正在从节点创建连线")
            }
        }
    }

    @ViewBuilder
    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let index = graph.nodes.firstIndex(where: { $0.id == selectedNodeID }) {
                    Text("已选节点").font(.headline)
                    Picker("图形类型", selection: $graph.nodes[index].kind) {
                        ForEach(FlowchartNodeKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    TextField("节点文字", text: $graph.nodes[index].label, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("从此节点创建连线") {
                        connectionSourceID = graph.nodes[index].id
                    }
                    Button("删除节点", role: .destructive) {
                        graph.removeNode(id: graph.nodes[index].id)
                        selectedNodeID = nil
                    }
                } else if let edge = graph.edges.first(where: { $0.id == selectedEdgeID }) {
                    Text("已选连线").font(.headline)
                    TextField("连线文字", text: edgeBinding(edge.id, keyPath: \.label))
                        .textFieldStyle(.roundedBorder)
                    Button("删除连线", role: .destructive) {
                        graph.edges.removeAll { $0.id == edge.id }
                        selectedEdgeID = nil
                    }
                } else {
                    Text("选择一个节点进行编辑").foregroundStyle(.secondary)
                }
                if !graph.edges.isEmpty {
                    Divider()
                    Text("连线").font(.headline)
                    ForEach(graph.edges) { edge in
                        Button("\(nodeName(edge.sourceID)) → \(nodeName(edge.targetID))") {
                            selectedEdgeID = edge.id
                            selectedNodeID = nil
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func select(_ node: FlowchartNode) {
        if let sourceID = connectionSourceID {
            graph.addEdge(from: sourceID, to: node.id)
            connectionSourceID = nil
            selectedNodeID = node.id
        } else {
            selectedNodeID = node.id
            selectedEdgeID = nil
        }
    }

    private func addNode(_ kind: FlowchartNodeKind) {
        let offset = Double(graph.nodes.count % 5) * 0.04
        graph.nodes.append(.init(kind: kind, frame: .init(x: 0.32 + offset, y: 0.32 + offset, width: 0.22, height: 0.12)))
    }

    private func nodeCenter(_ node: FlowchartNode, size: CGSize) -> CGPoint {
        CGPoint(x: (node.frame.x + node.frame.width / 2) * size.width,
                y: (node.frame.y + node.frame.height / 2) * size.height)
    }

    private func nodeName(_ id: UUID) -> String {
        graph.nodes.first(where: { $0.id == id })?.label.isEmpty == false
            ? graph.nodes.first(where: { $0.id == id })!.label
            : graph.nodes.first(where: { $0.id == id })?.kind.displayName ?? "节点"
    }

    private func edgeBinding(_ id: UUID, keyPath: WritableKeyPath<FlowchartEdge, String>) -> Binding<String> {
        Binding(
            get: { graph.edges.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { value in
                guard let index = graph.edges.firstIndex(where: { $0.id == id }) else { return }
                graph.edges[index][keyPath: keyPath] = value
            })
    }
}

private struct FlowchartNodeView: View {
    let node: FlowchartNode
    let selected: Bool
    let connecting: Bool

    var body: some View {
        ZStack {
            FlowchartSymbol(kind: node.kind)
                .fill(Color.white)
                .overlay(FlowchartSymbol(kind: node.kind).stroke(selected ? Color.accentColor : (node.isUncertain ? .orange : .primary), style: StrokeStyle(lineWidth: selected ? 4 : 2, dash: node.isUncertain ? [6, 4] : [])))
            Text(node.label.isEmpty ? node.kind.displayName : node.label)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(6)
        }
        .overlay {
            if connecting { RoundedRectangle(cornerRadius: 8).stroke(.green, lineWidth: 4) }
        }
    }
}

private struct FlowchartSymbol: Shape {
    let kind: FlowchartNodeKind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .terminator: return Path(roundedRect: rect, cornerRadius: rect.height / 2)
        case .decision:
            var path = Path(); path.move(to: .init(x: rect.midX, y: rect.minY)); path.addLine(to: .init(x: rect.maxX, y: rect.midY)); path.addLine(to: .init(x: rect.midX, y: rect.maxY)); path.addLine(to: .init(x: rect.minX, y: rect.midY)); path.closeSubpath(); return path
        case .inputOutput, .manualInput:
            var path = Path(); let offset = rect.width * 0.15; path.move(to: .init(x: rect.minX + offset, y: rect.minY)); path.addLine(to: .init(x: rect.maxX, y: rect.minY)); path.addLine(to: .init(x: rect.maxX - offset, y: rect.maxY)); path.addLine(to: .init(x: rect.minX, y: rect.maxY)); path.closeSubpath(); return path
        case .connector: return Path(ellipseIn: rect)
        case .preparation:
            var path = Path(); let inset = rect.width * 0.16; path.move(to: .init(x: rect.minX + inset, y: rect.minY)); path.addLine(to: .init(x: rect.maxX - inset, y: rect.minY)); path.addLine(to: .init(x: rect.maxX, y: rect.midY)); path.addLine(to: .init(x: rect.maxX - inset, y: rect.maxY)); path.addLine(to: .init(x: rect.minX + inset, y: rect.maxY)); path.addLine(to: .init(x: rect.minX, y: rect.midY)); path.closeSubpath(); return path
        default: return Path(roundedRect: rect, cornerRadius: kind == .unknown ? 8 : 2)
        }
    }
}
