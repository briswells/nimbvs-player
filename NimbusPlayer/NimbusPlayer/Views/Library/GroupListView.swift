import SwiftUI

/// Displays a list of book groups with alphabetical section headers.
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
            ForEach(sectionLetters, id: \.self) { letter in
                let sectionGroups = groupsForLetter(letter)
                if !sectionGroups.isEmpty {
                    HStack {
                        Text(letter)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(NimbusTheme.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .id("group-\(letter)")

                    ForEach(sectionGroups) { group in
                        NavigationLink(value: group) {
                            GroupRowView(group: group)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, NimbusTheme.Dimensions.paddingMedium)
                    }
                }
            }
        }
    }

    var sectionLetters: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for group in groups {
            let key = letterFor(group.name)
            if seen.insert(key).inserted {
                result.append(key)
            }
        }
        return result.sorted()
    }

    private func groupsForLetter(_ letter: String) -> [LibraryViewModel.BookGroup] {
        groups.filter { letterFor($0.name) == letter }
    }

    private func letterFor(_ name: String) -> String {
        let first = String(name.prefix(1)).uppercased()
        return first.first?.isLetter == true ? first : "#"
    }
}

// MARK: - Section Index Overlay

/// The A-Z scrubber on the right edge, like iOS Contacts.
struct SectionIndexView: View {
    let letters: [String]
    let idPrefix: String
    let scrollProxy: ScrollViewProxy

    var body: some View {
        VStack(spacing: 1) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NimbusTheme.Colors.accentPink)
                    .frame(width: 16, height: 14)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(NimbusTheme.Colors.backgroundDark.opacity(0.8))
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !letters.isEmpty else { return }
                    let itemHeight: CGFloat = 15
                    let totalHeight = CGFloat(letters.count) * itemHeight + 8
                    let fraction = max(0, min(1, value.location.y / totalHeight))
                    let index = min(letters.count - 1, max(0, Int(fraction * CGFloat(letters.count))))
                    let target = "\(idPrefix)\(letters[index])"
                    withAnimation(.easeOut(duration: 0.1)) {
                        scrollProxy.scrollTo(target, anchor: .top)
                    }
                }
        )
    }
}
