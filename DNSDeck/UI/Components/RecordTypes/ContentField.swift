import SwiftUI

struct ContentField: View {
    let type: String
    @Binding var content: String
    @Binding var ptrHostname: String
    @Binding var caaValue: String
    @Binding var srvService: String
    @Binding var srvProto: String
    @Binding var srvDomain: String
    @Binding var srvTarget: String

    var body: some View {
        Group {
            switch type {
            case "TXT":
                NativeTextField(
                    placeholder: "TXT value",
                    text: $content,
                    axis: .vertical,
                    lineLimit: 4,
                    minHeight: 80
                )
            case "MX":
                NativeTextField(placeholder: "Mail server (e.g. mx1.example.com.)", text: $content)
            case "A":
                NativeTextField(placeholder: "IPv4 address (e.g. 8.8.8.8)", text: $content)
            case "AAAA":
                NativeTextField(placeholder: "IPv6 address (e.g. 2001:4860:4860::8888)", text: $content)
            case "CNAME":
                NativeTextField(placeholder: "Target hostname (e.g. app.example.com.)", text: $content)
            case "NS":
                NativeTextField(placeholder: "Authoritative nameserver (e.g. ns1.example.com.)", text: $content)
            case "SRV":
                SRVFields(
                    srvService: $srvService,
                    srvProto: $srvProto,
                    srvDomain: $srvDomain,
                    srvTarget: $srvTarget
                )
            case "PTR":
                NativeTextField(placeholder: "Host target (e.g. mail.example.com.)", text: $ptrHostname)
            case "CAA":
                NativeTextField(placeholder: "Issuer domain (e.g. letsencrypt.org)", text: $caaValue)
            default:
                NativeTextField(placeholder: "Value", text: $content)
            }
        }
    }
}
