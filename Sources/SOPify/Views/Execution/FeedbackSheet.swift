import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    let stepText: String
    @Binding var draft: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("On step")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(stepText)
                    .font(.headline)

                TextEditor(text: $draft)
                    .frame(minHeight: 160)
                    .padding(8)
                    #if os(macOS)
                    .background(Color(nsColor: .controlBackgroundColor))
                    #else
                    .background(Color(.secondarySystemBackground))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding()
            .navigationTitle("Feedback")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}

#Preview {
    FeedbackSheet(stepText: "Drink water", draft: .constant(""), onSave: { _ in })
}
