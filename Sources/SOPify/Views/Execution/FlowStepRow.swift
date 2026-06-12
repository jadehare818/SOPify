import SwiftUI

struct FlowStepRow: View {
    let step: Step
    let isCompleted: Bool
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: isCurrent ? 28 : 20))
                        } else if isCurrent {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text("\(step.order + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                )
                        } else {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text("\(step.order + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .frame(width: 32)

                    Text(step.text)
                        .font(isCurrent ? .title3.weight(.semibold) : .body)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)

                    Spacer()
                }
                .padding(.vertical, isCurrent ? 16 : 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
                )
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: isCurrent)
        .animation(.easeInOut(duration: 0.25), value: isCompleted)
    }
}

#Preview {
    VStack(spacing: 4) {
        FlowStepRow(step: Step(text: "Done step", order: 0), isCompleted: true, isCurrent: false, onTap: {})
        FlowStepRow(step: Step(text: "Current active step with longer text", order: 1), isCompleted: false, isCurrent: true, onTap: {})
        FlowStepRow(step: Step(text: "Future step", order: 2), isCompleted: false, isCurrent: false, onTap: {})
    }
    .padding()
}
