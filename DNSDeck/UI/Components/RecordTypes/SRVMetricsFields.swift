import SwiftUI

struct SRVMetricsFields: View {
    @Binding var srvPriority: Int
    @Binding var srvWeight: Int
    @Binding var srvPort: Int

    var body: some View {
        HStack(spacing: 12) {
            NativeNumericField(placeholder: "Priority", value: $srvPriority)
            NativeNumericField(placeholder: "Weight", value: $srvWeight)
            NativeNumericField(placeholder: "Port", value: $srvPort)
        }
        .onChange(of: srvPriority) { _, newValue in
            srvPriority = min(max(newValue, 0), 65535)
        }
        .onChange(of: srvWeight) { _, newValue in
            srvWeight = min(max(newValue, 0), 65535)
        }
        .onChange(of: srvPort) { _, newValue in
            srvPort = min(max(newValue, 1), 65535)
        }
    }
}
