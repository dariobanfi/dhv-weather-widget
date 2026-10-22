import Foundation
import SwiftSoup

public enum DHVError: Error, LocalizedError, Equatable {
    case noForecastFound
    case badResponse(Int)

    public var errorDescription: String? {
        switch self {
        case .noForecastFound: "The DHV page didn't contain a forecast the app recognises. The page layout may have changed."
        case .badResponse(let code): "dhv.de answered with HTTP \(code)."
        }
    }
}

/// Parses https://www.dhv.de/wetter/dhv-wetter/.
///
/// The page lists one accordion per region. Inside, each day starts with a
/// heading like "Do. 22.10.2026: Zwischenhoch, +/- windig", followed by
/// paragraphs (bold summary, notes, "Wind: …") and an `<hr>`.
/// Paragraphs carry `thumbs-up`, `thumbs-down` or `exclamation` classes.
///
/// Instead of splitting raw HTML on "<hr>", the parser walks headings,
/// paragraphs and rules in document order, so extra wrappers or attributes
/// don't break it.
public struct DHVParser {
    public var calendar: Calendar
    public var now: Date

    public init(calendar: Calendar = .dhv, now: Date = .now) {
        self.calendar = calendar
        self.now = now
    }

    public func parse(html: String) throws -> Forecast {
        let doc = try SwiftSoup.parse(html)
        let pageText = try doc.text()
        let (issued, next) = parseStand(in: pageText)
        let reference = issued ?? now

        // Prefer the region accordions; fall back to the whole page if the
        // accordion markup ever goes away.
        let containers = try doc.select(".accordion-container").array()
        let scopes: [Element] = containers.isEmpty ? [doc.body()].compactMap { $0 } : containers

        var segments: [(RegionID, [DayForecast])] = []
        var currentRegion: RegionID?
        var currentDay: DayForecast?

        func closeDay() {
            guard let day = currentDay, let region = currentRegion else { currentDay = nil; return }
            if let i = segments.lastIndex(where: { $0.0 == region }), i == segments.count - 1 {
                segments[i].1.append(day)
            } else {
                segments.append((region, [day]))
            }
            currentDay = nil
        }

        for scope in scopes {
            for el in try scope.select("h1, h2, h3, h4, h5, p, hr").array() {
                let tag = el.tagName().lowercased()
                if tag == "hr" { closeDay(); continue }

                let text = Self.clean(try el.text())
                if text.isEmpty { continue }
                let isHeading = tag.hasPrefix("h")

                // A dated line ("Do. 22.10.2026: …") opens a new day, whether
                // DHV marks it up as a heading or as a paragraph.
                if let (date, headline) = parseDayHeading(text, reference: reference) {
                    closeDay()
                    if currentRegion != nil {
                        currentDay = DayForecast(date: date, headline: headline, signals: signals(of: el))
                    }
                    continue
                }

                if isHeading {
                    if text.count <= 60, let region = RegionID.match(text) {
                        closeDay()
                        currentRegion = region
                        continue
                    }
                    if currentDay != nil, tag == "h4" || tag == "h5" {
                        // Sub-heading inside a day (e.g. "Bassano"): keep it as text.
                        add(paragraph: el, text: text, to: &currentDay!)
                        continue
                    }
                    closeDay()
                    // Inside a region accordion, other headings are just notes.
                    // On the whole-page fallback they end the region's section.
                    if containers.isEmpty { currentRegion = nil }
                    continue
                }

                guard currentDay != nil else { continue }
                add(paragraph: el, text: text, to: &currentDay!)
            }
            closeDay()
            currentRegion = nil
        }

        // Keep the first section of each region that actually has days
        // (explanatory sections further down mention region names too).
        var regions: [RegionForecast] = []
        for (region, days) in segments where !days.isEmpty && !regions.contains(where: { $0.region == region }) {
            regions.append(RegionForecast(region: region, days: days.sorted { $0.date < $1.date }))
        }
        regions.sort { lhs, rhs in
            RegionID.allCases.firstIndex(of: lhs.region)! < RegionID.allCases.firstIndex(of: rhs.region)!
        }

        guard !regions.isEmpty else { throw DHVError.noForecastFound }
        return Forecast(regions: regions, issuedAt: issued, nextUpdateAt: next, fetchedAt: now)
    }

    // MARK: - Paragraphs

    /// DHV writes a day as one paragraph whose lines are separated by `<br>`:
    /// the summary (key phrase in `<strong>`), optional site notes such as
    /// "Bassano: …", and "Wind: …". Older markup used one `<p>` per line;
    /// both shapes end up as the same lines here.
    private func add(paragraph el: Element, text: String, to day: inout DayForecast) {
        day.signals.formUnion(signals(of: el))

        for runs in Self.lines(of: el) {
            let line = Self.clean(runs.map(\.text).joined())
            if line.isEmpty { continue }

            if let range = line.range(of: #"^Wind\s*:\s*"#, options: [.regularExpression, .caseInsensitive]) {
                let wind = String(line[range.upperBound...])
                day.wind = day.wind.map { "\($0) \(wind)" } ?? wind
                continue
            }

            var body = line
            if let range = line.range(of: #"^TREND\b\s*:?\s*"#, options: [.regularExpression, .caseInsensitive]) {
                day.isTrend = true
                body = String(line[range.upperBound...])
                if body.isEmpty { continue }
            }

            // "Bassano: …", "Dolomiten: …" are notes for a single site.
            let isSiteNote = body.range(of: #"^[A-ZÄÖÜ][\p{L}/ .-]{1,24}:\s"#, options: .regularExpression) != nil
            if day.summary == nil, !isSiteNote {
                day.summary = body
                day.emphasis = Self.emphasis(in: runs)
            } else {
                day.details.append(body)
            }
        }
    }

    struct Run: Equatable {
        var text: String
        var bold: Bool
    }

    /// Splits an element's content into lines at `<br>`, keeping which parts are bold.
    static func lines(of el: Element) -> [[Run]] {
        var lines: [[Run]] = [[]]
        func walk(_ node: Node, bold: Bool) {
            if let text = node as? TextNode {
                lines[lines.count - 1].append(Run(text: text.getWholeText(), bold: bold))
            } else if let e = node as? Element {
                let tag = e.tagName().lowercased()
                if tag == "br" { lines.append([]); return }
                let isBold = bold || tag == "strong" || tag == "b"
                for child in e.getChildNodes() { walk(child, bold: isBold) }
            }
        }
        for child in el.getChildNodes() { walk(child, bold: false) }
        return lines.filter { !$0.isEmpty }
    }

    /// The bold phrases DHV highlights in a line. A highlight that starts or
    /// ends inside a word ("sons<strong>t wechselnd</strong>") is widened to
    /// the whole word; the "TREND" label is dropped.
    static func emphasis(in runs: [Run]) -> [String] {
        var phrases: [String] = []
        var i = 0
        while i < runs.count {
            guard runs[i].bold else { i += 1; continue }
            var phrase = ""
            let start = i
            while i < runs.count, runs[i].bold { phrase += runs[i].text; i += 1 }

            if start > 0, let first = phrase.first, first.isLetter {
                let before = runs[start - 1].text
                let prefix = before.reversed().prefix { $0.isLetter }
                phrase = String(prefix.reversed()) + phrase
            }
            if i < runs.count, let last = phrase.last, last.isLetter {
                phrase += runs[i].text.prefix { $0.isLetter }
            }

            var cleaned = clean(phrase)
            if let r = cleaned.range(of: #"^TREND\b\s*:?\s*"#, options: [.regularExpression, .caseInsensitive]) {
                cleaned = String(cleaned[r.upperBound...])
            }
            cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " :,"))
            if cleaned.count >= 3 { phrases.append(cleaned) }
        }
        return phrases
    }

    /// Reads markers from class names, image sources and data attributes of
    /// the element and its children, never from the visible text.
    func signals(of el: Element) -> Set<Signal> {
        var hints = ""
        let nodes = (try? el.getAllElements().array()) ?? [el]
        for node in nodes {
            hints += " " + ((try? node.className()) ?? "")
            hints += " " + ((try? node.attr("src")) ?? "")
            hints += " " + ((try? node.attr("data-type")) ?? "")
        }
        hints = hints.lowercased()
        var result: Set<Signal> = []
        if hints.contains("thumbs-up") || hints.contains("thumbs_up") || hints.contains("thumbsup") { result.insert(.thermal) }
        if hints.contains("thumbs-down") || hints.contains("thumbs_down") || hints.contains("thumbsdown") { result.insert(.disturbed) }
        if hints.contains("exclamation") { result.insert(.warning) }
        return result
    }

    // MARK: - Dates

    private static let dayHeadingRegex = try! NSRegularExpression(
        pattern: #"^(Mo|Di|Mi|Do|Fr|Sa|So)\.?\s*(\d{1,2})\.(\d{1,2})\.(\d{2,4})?\s*:?\s*(.*)$"#,
        options: [.caseInsensitive]
    )

    func parseDayHeading(_ text: String, reference: Date) -> (Date, String)? {
        let ns = text as NSString
        guard let m = Self.dayHeadingRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        func group(_ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        guard let day = group(2).flatMap(Int.init), let month = group(3).flatMap(Int.init),
              let date = makeDate(day: day, month: month, year: group(4).flatMap(Int.init), hour: 12, minute: 0, reference: reference)
        else { return nil }
        let headline = Self.clean(group(5) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: ":-–— "))
        return (date, headline)
    }

    private static let standRegex = try! NSRegularExpression(
        pattern: #"Stand\s*:?\s*(?:[A-Za-z]{2}\.?\s*)?(\d{1,2})\.(\d{1,2})\.(\d{2,4})\s*[-–]\s*(\d{1,2})[:.](\d{2})"#,
        options: [.caseInsensitive]
    )
    private static let nextUpdateRegex = try! NSRegularExpression(
        pattern: #"Aktualisierung\s*:?\s*(?:[A-Za-z]{2}\.?\s*)?(\d{1,2})\.(\d{1,2})\.(\d{2,4})\s*[-–]\s*(\d{1,2})[:.](\d{2})"#,
        options: [.caseInsensitive]
    )

    /// Reads "Stand: Do. 22.10.26 - 16:00 h" and
    /// "Nächste Aktualisierung: Fr. 23.10.26 - 08:00 h".
    func parseStand(in text: String) -> (Date?, Date?) {
        func first(_ regex: NSRegularExpression) -> Date? {
            let ns = text as NSString
            guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
            let g = (1...5).map { Int(ns.substring(with: m.range(at: $0))) }
            guard let d = g[0], let mo = g[1], let y = g[2], let h = g[3], let mi = g[4] else { return nil }
            return makeDate(day: d, month: mo, year: y, hour: h, minute: mi, reference: now)
        }
        let issued = first(Self.standRegex)
        var next = first(Self.nextUpdateRegex)
        if let n = next, let i = issued, n <= i { next = nil }
        return (issued, next)
    }

    func makeDate(day: Int, month: Int, year: Int?, hour: Int, minute: Int, reference: Date) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
        var comps = DateComponents(month: month, day: day, hour: hour, minute: minute)
        if let year {
            comps.year = year < 100 ? 2000 + year : year
            return calendar.date(from: comps)
        }
        // No year printed: pick the year that puts the date closest to the
        // reference, so a 31.12 → 01.01 rollover lands in the right year.
        let refYear = calendar.component(.year, from: reference)
        return [refYear - 1, refYear, refYear + 1]
            .compactMap { y -> Date? in comps.year = y; return calendar.date(from: comps) }
            .min { abs($0.timeIntervalSince(reference)) < abs($1.timeIntervalSince(reference)) }
    }

    static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
