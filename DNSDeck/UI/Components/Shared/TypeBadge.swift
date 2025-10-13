import SwiftUI

struct TypeBadge: View {
    let type: String

    var body: some View {
        Text(type.uppercased())
            .font(.caption.weight(.semibold).monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(badgeColor(for: type))
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(badgeColor(for: type), lineWidth: 1)
            )
            .help(type)
    }

    private func badgeColor(for type: String) -> Color {
        switch type.uppercased() {
        case "A": .purple
        case "AAAA": .purple
        case "CNAME": .teal
        case "TXT": .gray
        case "MX": .blue
        case "NS": .gray
        case "SRV": .gray
        case "CAA": .red
        default: .gray
        }
    }
}
