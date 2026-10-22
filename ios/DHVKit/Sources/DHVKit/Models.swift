import Foundation

/// The three forecast areas published on dhv.de/wetter.
public enum RegionID: String, Codable, CaseIterable, Sendable, Identifiable {
    case deutschland
    case nordalpen
    case suedalpen

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .deutschland: "Deutschland"
        case .nordalpen: "Nordalpen"
        case .suedalpen: "Südalpen"
        }
    }

    /// Compact label for tight layouts.
    public var shortName: String {
        switch self {
        case .deutschland: "DE"
        case .nordalpen: "Nord"
        case .suedalpen: "Süd"
        }
    }

    /// Matches a heading such as "Deutschland", "Nordalpen" or "Südalpen".
    static func match(_ text: String) -> RegionID? {
        let t = text.lowercased()
        if t.contains("nordalpen") { return .nordalpen }
        if t.contains("südalpen") || t.contains("suedalpen") || t.contains("sudalpen") { return .suedalpen }
        if t.contains("deutschland") { return .deutschland }
        return nil
    }
}

/// Markers DHV attaches to forecast paragraphs (the "Thermikwetter",
/// "Störungswetter" and "Warnhinweis" filters on the page).
public enum Signal: String, Codable, Sendable, CaseIterable {
    case thermal    // thumbs-up: usable thermal weather
    case disturbed  // thumbs-down: frontal / disturbed weather
    case warning    // exclamation: warning (wind, föhn, storms)
}

/// Overall verdict for a day, derived from all its paragraphs instead of
/// letting the last paragraph overwrite the others.
public enum Rating: String, Codable, Sendable {
    case good       // only thermal markers
    case mixed      // thermal and disturbed markers on the same day
    case poor       // only disturbed markers
    case neutral    // no markers
}

public struct DayForecast: Codable, Equatable, Sendable, Identifiable {
    /// Noon of the forecast day in Europe/Berlin, so DST shifts never move it to another day.
    public var date: Date
    /// Headline from the day heading, e.g. "Zwischenhoch, +/- windig".
    public var headline: String
    /// The day's summary line (first line of the forecast text).
    public var summary: String?
    /// The phrases DHV set in bold inside the summary: its key message.
    public var emphasis: [String]
    /// Remaining paragraphs in order (e.g. Bassano notes, TREND text).
    public var details: [String]
    /// Text after "Wind:".
    public var wind: String?
    /// True when the day is only a trend (usually day 3).
    public var isTrend: Bool
    public var signals: Set<Signal>

    public var id: Date { date }

    public init(date: Date, headline: String, summary: String? = nil, emphasis: [String] = [], details: [String] = [],
                wind: String? = nil, isTrend: Bool = false, signals: Set<Signal> = []) {
        self.date = date
        self.headline = headline
        self.summary = summary
        self.emphasis = emphasis
        self.details = details
        self.wind = wind
        self.isTrend = isTrend
        self.signals = signals
    }

    public var rating: Rating {
        switch (signals.contains(.thermal), signals.contains(.disturbed)) {
        case (true, false): .good
        case (true, true): .mixed
        case (false, true): .poor
        case (false, false): .neutral
        }
    }

    public var hasWarning: Bool { signals.contains(.warning) }

    /// Short text for tight layouts: DHV's bold key phrase, else the headline.
    public var keyPhrase: String {
        emphasis.isEmpty ? headline : emphasis.joined(separator: " … ")
    }

    /// Sky condition read from DHV's own wording (key phrase first, then the
    /// summary, then the headline). Only picks the icon; the rating colour
    /// comes solely from DHV's markers.
    public var sky: Sky {
        for text in [emphasis.joined(separator: " "), summary ?? "", headline] {
            if let sky = Sky.classify(text) { return sky }
        }
        return .unknown
    }

    /// "sehr windig", "stürmisch", "Sturm", "starker … Wind".
    public var isStormy: Bool {
        let t = [headline, summary ?? "", wind ?? ""].joined(separator: " ").lowercased()
        return ["sehr windig", "stürm", "sturm", "sehr stark"].contains { t.contains($0) }
    }
}

public enum Sky: String, Codable, Sendable {
    case thunder, snow, rain, showers, overcast, fog, foehn, partlyCloudy, sunny, unknown

    /// Most severe condition mentioned wins, so "stark bewölkt, aufkommender
    /// Regen" reads as rain.
    static func classify(_ text: String) -> Sky? {
        let t = text.lowercased()
        guard !t.isEmpty else { return nil }
        let rules: [(Sky, [String])] = [
            (.thunder, ["gewitter"]),
            (.snow, ["schnee"]),
            (.rain, ["regen", "regnerisch", "niederschl"]),
            (.showers, ["schauer"]),
            (.overcast, ["stark bewölkt", "bedeckt", "dicht bewölkt", "trüb"]),
            (.fog, ["nebel"]),
            (.foehn, ["föhn"]),
            (.partlyCloudy, ["aufgelockert", "wolkig", "bewölkt", "ac/ci", "as/ci", "wechselhaft", "wechselnd"]),
            (.sunny, ["sonnig", "freundlich", "wolkenlos", "klar", "hochdruck", "hoch "]),
        ]
        return rules.first { _, words in words.contains { t.contains($0) } }?.0
    }
}

public struct RegionForecast: Codable, Equatable, Sendable, Identifiable {
    public var region: RegionID
    public var days: [DayForecast]
    public var id: RegionID { region }

    public init(region: RegionID, days: [DayForecast]) {
        self.region = region
        self.days = days
    }

    public func day(on date: Date, calendar: Calendar = .dhv) -> DayForecast? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Days from `now`'s calendar day onwards; drops days that are already past.
    public func upcomingDays(from now: Date, calendar: Calendar = .dhv) -> [DayForecast] {
        let today = calendar.startOfDay(for: now)
        return days.filter { $0.date >= today }
    }
}

public struct Forecast: Codable, Equatable, Sendable {
    public var regions: [RegionForecast]
    /// "Stand" time printed on the page.
    public var issuedAt: Date?
    /// Announced next update, if printed.
    public var nextUpdateAt: Date?
    /// When this copy was downloaded.
    public var fetchedAt: Date

    public init(regions: [RegionForecast], issuedAt: Date? = nil, nextUpdateAt: Date? = nil, fetchedAt: Date = .now) {
        self.regions = regions
        self.issuedAt = issuedAt
        self.nextUpdateAt = nextUpdateAt
        self.fetchedAt = fetchedAt
    }

    public func region(_ id: RegionID) -> RegionForecast? {
        regions.first { $0.region == id }
    }

    /// The forecast dates still ahead of `now`, across all regions, sorted.
    /// Columns are matched by date, so a region with fewer days leaves a gap
    /// instead of shifting into the wrong column.
    public func upcomingDates(from now: Date, limit: Int = 3, calendar: Calendar = .dhv) -> [Date] {
        var seen: [Date] = []
        for day in regions.flatMap({ $0.upcomingDays(from: now, calendar: calendar) }).map(\.date).sorted()
        where !seen.contains(where: { calendar.isDate($0, inSameDayAs: day) }) {
            seen.append(day)
        }
        return Array(seen.prefix(limit))
    }
}

public extension Calendar {
    /// Gregorian calendar in Europe/Berlin, which is what DHV dates refer to.
    static var dhv: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }
}

public enum DayLabel {
    /// "Today", "Tomorrow", or the weekday ("Saturday" / "Sat" when `short`).
    public static func text(for date: Date, now: Date, short: Bool = false, calendar: Calendar = .dhv) -> String {
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch diff {
        case 0: return "Today"
        case 1: return short ? "Tmrw" : "Tomorrow"
        case -1: return "Yesterday"
        default:
            let f = DateFormatter()
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = short ? "EEE" : "EEEE"
            return f.string(from: date)
        }
    }
}
