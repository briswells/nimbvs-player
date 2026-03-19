import SwiftUI

struct AddServerView: View {
    var isOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            Text("Add Server")
                .navigationTitle(isOnboarding ? "Welcome" : "Add Server")
        }
    }
}

#Preview {
    AddServerView()
}

#Preview("Onboarding") {
    AddServerView(isOnboarding: true)
}
