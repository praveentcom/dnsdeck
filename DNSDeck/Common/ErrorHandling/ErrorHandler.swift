import Combine
import Foundation
import SwiftUI

@MainActor
class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var isShowingError = false

    func handle(_ error: Error) {
        let appError: AppError = if let existingAppError = error as? AppError {
            existingAppError
        } else {
            .unknown(error)
        }

        currentError = appError
        isShowingError = true

        // Log the error
        Logger.logError(error, context: "ErrorHandler")
    }

    func clearError() {
        currentError = nil
        isShowingError = false
    }

    func handleAsync<T>(_ operation: @escaping () async throws -> T) async -> T? {
        do {
            return try await operation()
        } catch {
            handle(error)
            return nil
        }
    }
}

extension View {
    func withErrorHandling(_ errorHandler: ErrorHandler) -> some View {
        errorAlert(
            isPresented: Binding(
                get: { errorHandler.isShowingError },
                set: { _ in errorHandler.clearError() }
            ),
            title: "Error",
            message: errorHandler.currentError?.localizedDescription ?? "An unknown error occurred",
            onDismiss: {
                errorHandler.clearError()
            }
        )
    }
}
