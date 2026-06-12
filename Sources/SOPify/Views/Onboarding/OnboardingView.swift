import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]

    let onFinish: () -> Void

    private let templates = SOPTemplate.loadBundled()

    @State private var selectedTemplateIds: Set<String> = []

    private var groupedTemplates: [(String, [SOPTemplate])] {
        let groups = Dictionary(grouping: templates, by: \.category)
        let order = ["生活", "工作", "运动", "心理", "出行"]
        return order.compactMap { key in
            guard let items = groups[key] else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Welcome to SOPify")
                        .font(.largeTitle.bold())
                    Text("Pick a few starter templates, or skip to start fresh.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.bottom, 24)

                List {
                    ForEach(groupedTemplates, id: \.0) { group in
                        Section(group.0) {
                            ForEach(group.1) { template in
                                OnboardingTemplateRow(
                                    template: template,
                                    isSelected: selectedTemplateIds.contains(template.id)
                                ) {
                                    if selectedTemplateIds.contains(template.id) {
                                        selectedTemplateIds.remove(template.id)
                                    } else {
                                        selectedTemplateIds.insert(template.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                VStack(spacing: 12) {
                    Button {
                        importSelected()
                        onFinish()
                    } label: {
                        Text(selectedTemplateIds.isEmpty ? "Skip" : "Add \(selectedTemplateIds.count) Template\(selectedTemplateIds.count == 1 ? "" : "s")")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    if !selectedTemplateIds.isEmpty {
                        Button("Skip") {
                            onFinish()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }

    private func importSelected() {
        for template in templates where selectedTemplateIds.contains(template.id) {
            let sop = SOP(name: template.name, type: template.sopType)
            sop.category = categories.first(where: { $0.name == template.category })
            sop.steps = template.steps.enumerated().map { (i, text) in
                Step(text: text, order: i)
            }
            context.insert(sop)
        }
        try? context.save()
    }
}

private struct OnboardingTemplateRow: View {
    let template: SOPTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .foregroundStyle(.primary)
                    Text("\(template.steps.count) steps · \(template.type)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)
            }
        }
    }
}
