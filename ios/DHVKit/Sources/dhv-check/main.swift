import DHVKit
import Foundation

// Fetches the live DHV page and prints what the widget would show.
// Run with: swift run dhv-check
let cal = Calendar.dhv
let stamp = DateFormatter()
stamp.timeZone = cal.timeZone
stamp.dateFormat = "EEE dd.MM.yyyy HH:mm"

// `dhv-check --html` prints the raw markup the parser works on, to adapt it
// when DHV changes the page.
if CommandLine.arguments.contains("--html") {
    let html = try await DHVClient().fetchHTML()
    if let r = html.range(of: "Stand") {
        print("--- around \"Stand\":")
        print(html[html.index(r.lowerBound, offsetBy: -600, limitedBy: html.startIndex) ?? html.startIndex ..< (html.index(r.upperBound, offsetBy: 600, limitedBy: html.endIndex) ?? html.endIndex)])
    }
    var rest = html[...]
    for i in 1...2 {
        guard let r = rest.range(of: "accordion-container") else { break }
        let end = rest.index(r.lowerBound, offsetBy: 7000, limitedBy: rest.endIndex) ?? rest.endIndex
        print("\n--- accordion \(i):")
        print(rest[r.lowerBound..<end])
        rest = rest[r.upperBound...]
    }
    exit(0)
}

do {
    let forecast = try await DHVClient().fetch()
    print("Stand: \(forecast.issuedAt.map(stamp.string(from:)) ?? "not found")")
    print("Next update: \(forecast.nextUpdateAt.map(stamp.string(from:)) ?? "not found")")
    for region in forecast.regions {
        print("\n== \(region.region.name) (\(region.days.count) days)")
        for day in region.days {
            let label = DayLabel.text(for: day.date, now: .now)
            let marks = day.signals.map(\.rawValue).sorted().joined(separator: ",")
            print("  \(label) [\(day.rating.rawValue)\(marks.isEmpty ? "" : " " + marks)]\(day.isTrend ? " TREND" : "")")
            print("    headline: \(day.headline)")
            if let s = day.summary { print("    summary:  \(s)") }
            for d in day.details { print("    detail:   \(d)") }
            if let w = day.wind { print("    wind:     \(w)") }
        }
    }
    let total = forecast.regions.reduce(0) { $0 + $1.days.count }
    if forecast.regions.count < 3 || total < 5 {
        print("\nWARNING: expected 3 regions with at least 5 days in total.")
        exit(2)
    }
} catch {
    print("ERROR: \(error.localizedDescription)")
    exit(1)
}
