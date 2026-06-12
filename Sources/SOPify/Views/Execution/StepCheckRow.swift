import SwiftUI

struct StepCheckRow: View {
    let step: Step
    let isCompleted: Bool
    let isCurrent: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(isCurrent ? .system(size: 32) : .system(size: 24))
                    .foregroundStyle(isCompleted ? .green : (isCurrent ? .accentColor : .secondary))
            }
            .buttonStyle(.plain)

            Text(step.text)
                .font(isCurrent ? .title3.weight(.semibold) : .body)
                .foregroundStyle(isCompleted ? .secondary : .primary)
                .strikethrough(isCompleted)

            Spacer()
        }
        .padding(.vertical, isCurrent ? 12 : 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}

#Preview {
    let step = Step(text: "Pack swim trunks", order: 0)
    return VStack(spacing: 8) {
        StepCheckRow(step: step, isCompleted: true, isCurrent: false, onToggle: {})
        StepCheckRow(step: step, isCompleted: false, isCurrent: true, onToggle: {})
        StepCheckRow(step: step, isCompleted: false, isCurrent: false, onToggle: {})
    }.padding()
}
