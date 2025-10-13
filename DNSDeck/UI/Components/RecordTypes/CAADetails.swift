import SwiftUI

struct CAADetails: View {
    @Binding var caaFlags: Int
    @Binding var caaTag: String
    @Binding var caaValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(value: $caaFlags, in: 0 ... 255) {
                HStack {
                    Text("Flags")
                    Spacer()
                    Text(String(caaFlags))
                        .monospacedDigit()
                }
            }

            Picker("Tag", selection: $caaTag) {
                ForEach(["issue", "issuewild", "iodef"], id: \.self) { tag in
                    Text(tag).tag(tag)
                }
            }
            .pickerStyle(.segmented)
            #if os(iOS)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            #endif
        }
    }
}
