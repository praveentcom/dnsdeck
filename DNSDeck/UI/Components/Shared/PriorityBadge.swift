import SwiftUI

struct PriorityBadge: View {
    let priority: Int?

    var body: some View {
        Text(priority.map(String.init) ?? "—")
            .foregroundStyle(Color.primary)
            .font(.caption.weight(.semibold).monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.primary, lineWidth: 1)
            )
    }
}
