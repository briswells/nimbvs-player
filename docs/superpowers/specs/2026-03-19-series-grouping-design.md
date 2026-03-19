# Library Grouping & Series Search — Design Specification

## Overview

Add group-by modes to the Library tab (Series, Authors, Narrators) with two-level navigation, and enhance Search to surface series results.

## Library Grouping

### Group-By Picker

A segmented control or menu in the Library toolbar: `All Books | Series | Authors | Narrators`

- **All Books**: Current flat grid/list behavior with sort options
- **Series / Authors / Narrators**: Two-level navigation — first a list of groups, tap to drill into books

### Group List View

When a grouping mode is selected, the Library shows a scrollable list of groups. Each group row shows:
- Cover thumbnail from the first book in the group
- Group name (series name, author name, or narrator name)
- Book count (e.g., "9 books")

Groups sorted alphabetically. Groups with only 1 book are included.

### Parsing Series Data

The Audiobookshelf API provides `metadata.seriesName` as a pre-computed string like `"The Expanse #3"` or `"DUNE: The Schools of Dune Trilogy #1"`. Books can belong to multiple series (comma-separated or multiple entries).

Parsing logic:
- Split `seriesName` on `#` — text before is the series name, text after is the sequence
- Trim whitespace from both parts
- If no `#`, the entire string is the series name with no sequence
- A book with no `seriesName` does not appear in the Series grouping

Note: `CachedBook` already stores `seriesName` and `seriesSequence`. The current `LibraryService.persistBooks` sets these from `item.seriesName` and `item.seriesSequence` (computed properties on `LibraryItemResponse` that read `metadata.series[0].name` and `metadata.series[0].sequence`). However, the API data shows `metadata.series` is often empty while `metadata.seriesName` has data. We need to also parse `metadata.seriesName` as a fallback.

### Group Detail View

A shared detail view used for all three grouping types:
- Header: group name, book count
- Book list with cover thumbnail, title, author, duration, progress indicator
- **Series**: sorted by sequence number (numeric sort, then alphabetical for ties)
- **Authors / Narrators**: sorted by title

Navigation: tapping a book navigates to `BookDetailView`.

## Search Enhancement

Search results are displayed in sections:

1. **Series matches** (top) — series whose name contains the search query, shown as tappable cards that navigate to GroupDetailView
2. **Individual book matches** (below) — current behavior

Series matches are derived from:
- The search API's `series` response field (currently ignored), which returns series objects with their books
- Local filtering of cached books' `seriesName` field

## Files

| Action | File | Purpose |
|--------|------|---------|
| Create | `Views/Library/GroupListView.swift` | Two-level group list, reused for series/author/narrator |
| Create | `Views/Library/GroupDetailView.swift` | Books within a selected group |
| Create | `Views/Library/GroupRowView.swift` | Single row in the group list |
| Modify | `Views/Library/LibraryView.swift` | Add group-by picker, show GroupListView when grouped |
| Modify | `ViewModels/LibraryViewModel.swift` | Add grouping logic, parse seriesName into groups |
| Modify | `ViewModels/SearchViewModel.swift` | Include series in search results |
| Modify | `Views/Search/SearchView.swift` | Add series section above book results |
| Modify | `Models/API/LibraryItemResponse.swift` | Fallback to `metadata.seriesName` parsing |
| Modify | `Services/LibraryService.swift` | Persist parsed seriesName from API fallback |

## No Model Changes

`CachedBook` already has `seriesName: String?`, `seriesSequence: String?`, `author: String`, `narrator: String?`. No SwiftData migration needed.
