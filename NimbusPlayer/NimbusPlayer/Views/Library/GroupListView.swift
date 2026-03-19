import SwiftUI

/// Displays a list of book groups with an alphabetical section index on the right.
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
            ZStack(alignment: .trailing) {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 0) {
                        ForEach(sectionLetters, id: \.self) { letter in
                            let sectionGroups = groupsForLetter(letter)
                            if !sectionGroups.isEmpty {
                                // Section header
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
                                .id(letter)

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
                    .onChange(of: scrollToLetter) { _, letter in
                        if let letter {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(letter, anchor: .top)
                            }
                        }
                    }
                }

                // Section index
                SectionIndexView(
                    letters: activeLetters,
                    onSelect: { letter in
                        scrollToLetter = letter
                    }
                )
                .padding(.trailing, 2)
            }
        }
    }

    // MARK: - State

    @State private var scrollToLetter: String?

    // MARK: - Computed

    private var sectionLetters: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for group in groups {
            let letter = String(group.name.prefix(1)).uppercased()
            let key = letter.first?.isLetter == true ? letter : "#"
            if seen.insert(key).inserted {
                result.append(key)
            }
        }
        return result.sorted()
    }

    private var activeLetters: [String] {
        sectionLetters
    }

    private func groupsForLetter(_ letter: String) -> [LibraryViewModel.BookGroup] {
        groups.filter { group in
            let first = String(group.name.prefix(1)).uppercased()
            if letter == "#" {
                return first.first?.isLetter != true
            }
            return first == letter
        }
    }
}

// MARK: - Section Index

/// The A-Z scrubber on the right edge, like iOS Contacts.
struct SectionIndexView: View {
    let letters: [String]
    let onSelect: (String) -> Void

    @GestureState private var isDragging = false

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
                .fill(NimbusTheme.Colors.surfaceOverlay)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let totalHeight = CGFloat(letters.count) * 14 + 8
                    let fraction = max(0, min(1, value.location.y / totalHeight))
                    let index = min(letters.count - 1, Int(fraction * CGFloat(letters.count)))
                    if index >= 0 && index < letters.count {
                        onSelect(letters[index])
                    }
                }
        )
    }
}
