import SwiftUI

struct TypePicker: View {
    @Binding var type: String

    var body: some View {
        Menu {
            typeMenuOption(value: "A", label: "A — IPv4")
            typeMenuOption(value: "AAAA", label: "AAAA — IPv6")
            typeMenuOption(value: "CNAME", label: "CNAME — Alias")
            typeMenuOption(value: "MX", label: "MX — Mail exchange")
            typeMenuOption(value: "TXT", label: "TXT — Text record")
            typeMenuOption(value: "NS", label: "NS — Nameserver")
            typeMenuOption(value: "SRV", label: "SRV — Service locator")
            typeMenuOption(value: "PTR", label: "PTR — Reverse pointer")
            typeMenuOption(value: "CAA", label: "CAA — Certificate authority")
        } label: {
            HStack {
                Text(typeLabel(for: type))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            #if os(iOS)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            #endif
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func typeMenuOption(value: String, label: String) -> some View {
        Button {
            type = value
        } label: {
            HStack {
                Text(label)
                Spacer()
                if type == value {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func typeLabel(for type: String) -> String {
        switch type {
        case "A":
            "A — IPv4"
        case "AAAA":
            "AAAA — IPv6"
        case "CNAME":
            "CNAME — Alias"
        case "MX":
            "MX — Mail exchange"
        case "TXT":
            "TXT — Text record"
        case "NS":
            "NS — Nameserver"
        case "SRV":
            "SRV — Service locator"
        case "PTR":
            "PTR — Reverse pointer"
        case "CAA":
            "CAA — Certificate authority"
        default:
            type.uppercased()
        }
    }
}
