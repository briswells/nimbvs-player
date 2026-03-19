import Foundation
import SwiftData

// MARK: - ServerSetupViewModel

/// View model that drives the Add Server form, handling validation, login, and persistence.
@Observable
final class ServerSetupViewModel {

    // MARK: - Form Fields

    var serverURL: String = ""
    var username: String = ""
    var password: String = ""
    var displayName: String = ""

    // MARK: - State

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Computed

    /// Whether the form has enough information to attempt a connection.
    var isFormValid: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    // MARK: - Actions

    /// Validates inputs, authenticates with the server, persists the `Server` model, and registers
    /// the returned token with `ServerService`.
    ///
    /// - Parameters:
    ///   - serverService: The service managing API clients and tokens.
    ///   - modelContext: The SwiftData context used to insert the new `Server`.
    ///   - onComplete: Closure invoked on success so the caller can dismiss the view.
    @MainActor
    func addServer(serverService: ServerService, modelContext: ModelContext, onComplete: (() -> Void)? = nil) {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields."
            return
        }

        // Normalise the URL – prepend a scheme if none is provided.
        var urlString = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://\(urlString)"
        }
        // Strip trailing slash for consistency.
        if urlString.hasSuffix("/") {
            urlString = String(urlString.dropLast())
        }

        guard let url = URL(string: urlString) else {
            errorMessage = "The server URL is invalid."
            return
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = trimmedDisplayName.isEmpty ? url.host ?? urlString : trimmedDisplayName

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let (token, _) = try await serverService.login(url: url, username: trimmedUsername, password: password)

                let server = Server(url: urlString, username: trimmedUsername, displayName: resolvedDisplayName)
                modelContext.insert(server)

                try serverService.registerServer(server, token: token)

                isLoading = false
                onComplete?()
            } catch let error as APIError {
                isLoading = false
                errorMessage = error.errorDescription
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
