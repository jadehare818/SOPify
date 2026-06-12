import SwiftUI

struct StepEditRow: View {
    @Binding var text: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Step", text: $text, axis: .vertical)
                .lineLimit(1...4)
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    StepEditRow(text: .constant("Pack laptop"), onDelete: {})
        .padding()
}
