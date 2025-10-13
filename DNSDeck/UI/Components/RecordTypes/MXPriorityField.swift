import SwiftUI

struct MXPriorityField: View {
    @Binding var mxPriority: Int

    var body: some View {
        NativeNumericField(placeholder: "Priority", value: $mxPriority)
            .onChange(of: mxPriority) { _, newValue in
                mxPriority = min(max(newValue, 0), 65535)
            }
    }
}
