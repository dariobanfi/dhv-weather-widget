import AppIntents
import DHVKit
import WidgetKit

enum Timelines {
    /// One entry now, plus one just after each of the next two midnights so
    /// "Today" / "Tomorrow" roll over even if no refresh happens overnight.
    static func make(region: RegionID) async -> Timeline<ForecastEntry> {
        let now = Date.now
        // Several widgets reload together; reuse a copy fetched in the last 10 minutes.
        let result = await ForecastLoader.load(maxAge: 10 * 60, now: now)
        let base = ForecastEntry(date: now, forecast: result.forecast, error: result.error,
                                 isFromCache: result.isFromCache, region: region)

        let cal = Calendar.dhv
        var entries = [base]
        var midnight = cal.startOfDay(for: now)
        for _ in 0..<2 {
            guard let next = cal.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
            var entry = base
            entry.date = next.addingTimeInterval(60)
            entries.append(entry)
        }
        let refresh = ForecastLoader.nextRefresh(after: result.forecast, now: now, failed: result.error != nil)
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

// MARK: - All regions (medium / large)

struct OverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForecastEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping (ForecastEntry) -> Void) {
        if context.isPreview { completion(.sample()); return }
        Task { completion(await Timelines.make(region: .nordalpen).entries[0]) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ForecastEntry>) -> Void) {
        Task { completion(await Timelines.make(region: .nordalpen)) }
    }
}

// MARK: - Single region (small / Lock Screen)

enum RegionChoice: String, AppEnum {
    case deutschland, nordalpen, suedalpen

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Region"
    static let caseDisplayRepresentations: [RegionChoice: DisplayRepresentation] = [
        .deutschland: "Deutschland",
        .nordalpen: "Nordalpen",
        .suedalpen: "Südalpen",
    ]

    var regionID: RegionID { RegionID(rawValue: rawValue) ?? .nordalpen }
}

struct RegionIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Region"
    static let description = IntentDescription("Choose which DHV forecast region to show.")

    @Parameter(title: "Region", default: .nordalpen)
    var region: RegionChoice

    init() {}
}

struct RegionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ForecastEntry { .sample() }

    func snapshot(for configuration: RegionIntent, in context: Context) async -> ForecastEntry {
        if context.isPreview { return .sample(region: configuration.region.regionID) }
        return await Timelines.make(region: configuration.region.regionID).entries[0]
    }

    func timeline(for configuration: RegionIntent, in context: Context) async -> Timeline<ForecastEntry> {
        await Timelines.make(region: configuration.region.regionID)
    }
}
