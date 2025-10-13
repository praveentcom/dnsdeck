import SwiftUI

/// A text field that provides native styling for each platform
struct NativeTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: Int?
    var minHeight: CGFloat?

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .lineLimit(lineLimit)
        #if os(iOS)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(minHeight: minHeight, alignment: .top)
        #else
            .textFieldStyle(.roundedBorder)
            .frame(minHeight: minHeight, alignment: .top)
        #endif
    }
}

/// A secure field that provides native styling for each platform
struct NativeSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
        #if os(iOS)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        #else
            .textFieldStyle(.roundedBorder)
        #endif
    }
}

/// A numeric text field that provides native styling for each platform
struct NativeNumericField: View {
    let placeholder: String
    @Binding var value: Int
    var width: CGFloat?

    var body: some View {
        TextField(placeholder, value: $value, format: .number)
        #if os(iOS)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(width: width)
        #else
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
        #endif
    }
}

#Preview {
    VStack(spacing: 16) {
        NativeTextField(placeholder: "Enter text", text: .constant(""))

        NativeTextField(
            placeholder: "Multi-line text",
            text: .constant(""),
            axis: .vertical,
            lineLimit: 4,
            minHeight: 80
        )

        NativeSecureField(placeholder: "Password", text: .constant(""))

        NativeNumericField(
            placeholder: "Number",
            value: .constant(42),
            width: 120
        )
    }
    .padding()
}
