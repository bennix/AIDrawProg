import SwiftUI

struct InspectionHintView: View {
    let messages: [FlowchartInspection.Message]
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("可以再完善一步")
                    .font(.headline)
                ForEach(messages) { message in
                    Text(message.text)
                        .font(.subheadline)
                }
            }
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .accessibilityLabel("关闭提示")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
