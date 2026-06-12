import SwiftUI

struct SOPRowView: View {
    let sop: SOP

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sop.name)
                .font(.headline)
            Text("\(sop.steps.count) steps")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let sop = SOP(name: "Morning routine")
    sop.steps = [Step(text: "Brush teeth", order: 0), Step(text: "Drink water", order: 1)]
    return SOPRowView(sop: sop).padding()
}
