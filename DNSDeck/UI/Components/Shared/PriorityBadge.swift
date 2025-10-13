import SwiftUI

struct PriorityBadge: View {
    let priority: Int?

    var body: some View {
        Text(priority.map(String.init) ?? "—")
            .foregroundStyle(.blue)
            .font(.caption.weight(.semibold).monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(.blue, lineWidth: 1)
            )
    }
}
