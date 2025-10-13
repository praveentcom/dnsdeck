import SwiftUI

struct SRVFields: View {
    @Binding var srvService: String
    @Binding var srvProto: String
    @Binding var srvDomain: String
    @Binding var srvTarget: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NativeTextField(placeholder: "Service (e.g. _sip)", text: $srvService)

                Picker("Protocol", selection: $srvProto) {
                    ForEach(["_tcp", "_udp", "_tls"], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
                #if os(iOS)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                #endif
            }

            NativeTextField(placeholder: "Domain (e.g. example.com)", text: $srvDomain)

            NativeTextField(placeholder: "Target host (e.g. sip.example.com.)", text: $srvTarget)
        }
    }
}
