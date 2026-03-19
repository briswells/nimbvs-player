import SwiftUI

/// Displays a list of book groups (series, authors, or narrators) for two-level navigation.
struct GroupListView: View {
    let groups: [LibraryViewModel.BookGroup]

    var body: some View {
        if groups.isEmpty {
            ContentUnavailableView(
                "No Groups",
                systemImage: "rectangle.stack",
                description: Text("No books have this metadata.")
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(groups) { group in
                    NavigationLink(value: group) {
                        GroupRowView(group: group)
                    }
                    .buttonStyle(.plain)

                    if group.id != groups.last?.id {
                        Divider()
                            .background(NimbusTheme.Colors.divider)
                    }
                }
            }
            .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
        }
    }
}
