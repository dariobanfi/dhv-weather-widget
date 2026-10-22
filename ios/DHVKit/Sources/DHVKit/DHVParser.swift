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

    private func add(paragraph el: Element, text: String, to day: inout DayForecast) {
        day.signals.formUnion(signals(of: el))

        if let range = text.range(of: #"^Wind\s*:\s*"#, options: [.regularExpression, .caseInsensitive]) {
            let wind = String(text[range.upperBound...])
            day.wind = day.wind.map { "\($0) \(wind)" } ?? wind
            return
        }
        if text.range(of: #"^TREND\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            day.isTrend = true
        }

        // The first paragraph that opens with a bold sentence is the day's
        // summary. Short bold labels such as "Bassano:" stay details.
        let bold = Self.clean((try? el.select("strong, b").text()) ?? "")
        if day.summary == nil, bold.count >= 12, text.hasPrefix(String(bold.prefix(12))),
           Double(bold.count) >= Double(text.count) * 0.5 {
            day.summary = text
            return
        }
        day.details.append(text)
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

    private static let dateTimeRegex = try! NSRegularExpression(
        pattern: #"(\d{1,2})\.(\d{1,2})\.(\d{2,4})\s*[-–]\s*(\d{1,2})[:.](\d{2})"#
    )

    /// Finds "Stand: Do. 22.10.26 - 07:00 h" and the next announced update.
    func parseStand(in text: String) -> (Date?, Date?) {
        guard let standRange = text.range(of: "Stand", options: .caseInsensitive) else { return (nil, nil) }
        let tail = String(text[standRange.lowerBound...])
        let ns = tail as NSString
        let matches = Self.dateTimeRegex.matches(in: tail, range: NSRange(location: 0, length: min(ns.length, 400)))
        let dates: [Date] = matches.compactMap { m in
            let g = (1...5).map { Int(ns.substring(with: m.range(at: $0))) }
            guard let d = g[0], let mo = g[1], let y = g[2], let h = g[3], let mi = g[4] else { return nil }
            return makeDate(day: d, month: mo, year: y, hour: h, minute: mi, reference: now)
        }
        guard let issued = dates.first else { return (nil, nil) }
        return (issued, dates.dropFirst().first { $0 > issued })
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
