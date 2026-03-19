import Foundation

enum JaroWinkler {

    /// Case-insensitive Jaro-Winkler similarity between two strings.
    /// Returns a value from 0.0 (no similarity) to 1.0 (identical).
    static func similarity(_ s1: String, _ s2: String) -> Double {
        let a = Array(s1.lowercased())
        let b = Array(s2.lowercased())

        if a == b { return a.isEmpty ? 0.0 : 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }

        let jaroScore = jaro(a, b)

        // Winkler boost: common prefix up to 4 characters (contiguous)
        var commonPrefix = 0
        for i in 0..<min(4, min(a.count, b.count)) {
            if a[i] == b[i] {
                commonPrefix += 1
            } else {
                break
            }
        }

        let winklerScore = jaroScore + Double(commonPrefix) * 0.1 * (1.0 - jaroScore)
        return min(winklerScore, 1.0)
    }

    // MARK: - Private

    private static func jaro(_ s1: [Character], _ s2: [Character]) -> Double {
        let len1 = s1.count
        let len2 = s2.count

        let matchWindow = max(max(len1, len2) / 2 - 1, 0)

        var s1Matched = [Bool](repeating: false, count: len1)
        var s2Matched = [Bool](repeating: false, count: len2)

        var matches: Double = 0
        var transpositions: Double = 0

        // Find matching characters within the match window
        for i in 0..<len1 {
            let lo = max(0, i - matchWindow)
            let hi = min(i + matchWindow, len2 - 1)
            guard lo <= hi else { continue }
            for j in lo...hi {
                guard !s2Matched[j], s1[i] == s2[j] else { continue }
                s1Matched[i] = true
                s2Matched[j] = true
                matches += 1
                break
            }
        }

        if matches == 0 { return 0.0 }

        // Count transpositions
        var k = 0
        for i in 0..<len1 {
            guard s1Matched[i] else { continue }
            while !s2Matched[k] { k += 1 }
            if s1[i] != s2[k] { transpositions += 1 }
            k += 1
        }

        return (matches / Double(len1)
              + matches / Double(len2)
              + (matches - transpositions / 2.0) / matches) / 3.0
    }
}
