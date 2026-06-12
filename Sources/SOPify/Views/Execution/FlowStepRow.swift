import SwiftUI

struct FlowStepRow: View {
    let step: Step
    let isCompleted: Bool
    let isCurrent: Bool
    var isFocused: Bool = false
    let onTap: () -> Void
    var onDone: (() -> Void)? = nil

    private var isHighlighted: Bool { isCurrent || isFocused }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: isHighlighted ? 28 : 20))
                        } else if isHighlighted {
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.text)
                            .font(isHighlighted ? .title3.weight(.semibold) : .body)
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)

                        if isFocused && !isCompleted, let onDone {
                            Button(action: onDone) {
                                Label("Done", systemImage: "checkmark")
                                    .font(.subheadline.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                            .padding(.top, 2)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, isHighlighted ? 16 : 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHighlighted ? Color.accentColor.opacity(0.08) : Color.clear)
                )
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .animation(.easeInOut(duration: 0.25), value: isCompleted)
        .animation(.easeInOut(duration: 0.25), value: isFocused)
    }
}

#Preview {
    VStack(spacing: 4) {
        FlowStepRow(step: Step(text: "Done step", order: 0), isCompleted: true, isCurrent: false, onTap: {})
        FlowStepRow(step: Step(text: "Current step with Done button", order: 1), isCompleted: false, isCurrent: false, isFocused: true, onTap: {}, onDone: {})
        FlowStepRow(step: Step(text: "Future step", order: 2), isCompleted: false, isCurrent: false, onTap: {})
    }
    .padding()
}
