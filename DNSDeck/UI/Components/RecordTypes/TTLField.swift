import SwiftUI

struct TTLField: View {
    @Binding var ttlAuto: Bool
    @Binding var ttlValue: Int

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Automatic TTL", isOn: $ttlAuto)
            Spacer()
            NativeNumericField(
                placeholder: "Seconds",
                value: $ttlValue,
                width: 120
            )
            .disabled(ttlAuto)
            .opacity(ttlAuto ? 0.45 : 1)
        }
        .help("Cloudflare TTL of 1 means 'Automatic'.")
        .onChange(of: ttlValue) { _, newValue in
            ttlValue = min(max(newValue, 60), 86400)
        }
    }
}
