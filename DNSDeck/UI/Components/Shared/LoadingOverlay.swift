import SwiftUI

struct LoadingOverlay: View {
    let text: String
    let isVisible: Bool

    init(text: String = "Loading...", isVisible: Bool = true) {
        self.text = text
        self.isVisible = isVisible
    }

    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)

                    Text(text)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct LoadingOverlayModifier: ViewModifier {
    let text: String
    let isVisible: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            LoadingOverlay(text: text, isVisible: isVisible)
        }
    }
}

extension View {
    func loadingOverlay(text: String = "Loading...", isVisible: Bool = true) -> some View {
        modifier(LoadingOverlayModifier(text: text, isVisible: isVisible))
    }
}
