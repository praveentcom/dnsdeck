import SwiftUI

struct ErrorAlert: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let onDismiss: (() -> Void)?

    init(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        onDismiss: (() -> Void)? = nil
    ) {
        _isPresented = isPresented
        self.title = title
        self.message = message
        self.onDismiss = onDismiss
    }

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button("OK") {
                    onDismiss?()
                }
            } message: {
                Text(message)
            }
    }
}

extension View {
    func errorAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlert(
            isPresented: isPresented,
            title: title,
            message: message,
            onDismiss: onDismiss
        ))
    }
}
