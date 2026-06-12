import SwiftUI

struct CategoryCardView: View {
    let category: Category

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.title)
                .foregroundStyle(Color.accentColor)
            Text(category.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text("\(category.sops.count) SOPs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct UncategorizedCardView: View {
    let count: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("未分类")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text("\(count) SOPs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.systemGray5))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
