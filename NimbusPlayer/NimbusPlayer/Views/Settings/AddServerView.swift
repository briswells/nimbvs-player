import SwiftUI
import SwiftData

// MARK: - AddServerView

/// A form for connecting to an Audiobookshelf server.
///
/// Displayed during first-launch onboarding or from the settings screen.
struct AddServerView: View {

    // MARK: - Properties

    var isOnboarding: Bool = false
    var onComplete: (() -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(ServerService.self) private var serverService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ServerSetupViewModel()
    @FocusState private var focusedField: Field?

    // MARK: - Focus

    private enum Field: Hashable {
        case serverURL
        case displayName
        case username
        case password
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                credentialsSection
                errorSection
            }
            .navigationTitle(isOnboarding ? "Welcome" : "Add Server")
            .navigationBarTitleDisplayMode(isOnboarding ? .large : .inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    connectButton
                }
            }
            .scrollContentBackground(.hidden)
            .background(NimbusTheme.Colors.backgroundGrouped)
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        Section {
            TextField("Server URL", text: $viewModel.serverURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .serverURL)
                .onSubmit { focusedField = .displayName }

            TextField("Display Name (optional)", text: $viewModel.displayName)
                .focused($focusedField, equals: .displayName)
                .onSubmit { focusedField = .username }
        } header: {
            Text("Server")
        } footer: {
            Text("Enter the full address of your Audiobookshelf server, e.g. http://192.168.1.50:13378")
        }
    }

    private var credentialsSection: some View {
        Section("Credentials") {
            TextField("Username", text: $viewModel.username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .username)
                .onSubmit { focusedField = .password }

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .onSubmit { attemptConnect() }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button(action: attemptConnect) {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Text("Connect")
            }
        }
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
    }

    // MARK: - Actions

    private func attemptConnect() {
        focusedField = nil

        viewModel.addServer(serverService: serverService, modelContext: modelContext) {
            if let onComplete {
                onComplete()
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - Previews

#Preview {
    AddServerView()
        .environment(AppState())
        .environment(ServerService())
        .modelContainer(for: Server.self, inMemory: true)
}

#Preview("Onboarding") {
    AddServerView(isOnboarding: true)
        .environment(AppState())
        .environment(ServerService())
        .modelContainer(for: Server.self, inMemory: true)
}
