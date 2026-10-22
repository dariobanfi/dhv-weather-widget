import Foundation

public extension Forecast {
    /// Realistic placeholder content (based on the 22.10.2026 forecast),
    /// re-dated to start today, for widget placeholders and previews.
    static func sample(now: Date = .now, calendar: Calendar = .dhv) -> Forecast {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: noon) ?? noon }

        return Forecast(
            regions: [
                RegionForecast(region: .deutschland, days: [
                    DayForecast(date: day(0), headline: "Durchwachsen, zunehmend sehr windig",
                                summary: "Anfangs etwas aufgelockert, dann aus Westen stark bewölkt, sehr windig und etwas Regen.",
                                wind: "Zunehmend starker SW-Wind.", signals: [.disturbed, .warning]),
                    DayForecast(date: day(1), headline: "Sturmtief aus Westen",
                                summary: "Meist stark bewölkt, regnerisch und sehr windig.",
                                wind: "Starker bis stürmischer SW-Wind.", signals: [.disturbed, .warning]),
                ]),
                RegionForecast(region: .nordalpen, days: [
                    DayForecast(date: day(0), headline: "Zwischenhoch, +/- windig",
                                summary: "Aufgelockert, zeitweise freundlich, auflebender Westwind.",
                                wind: "Auflebender, oft böiger WNW-Wind.", signals: [.thermal, .warning]),
                    DayForecast(date: day(1), headline: "Föhnig, nächste Front im Westen",
                                summary: "Föhnig mit vielen As/Ci-Wolken, abends im Westen Front.",
                                wind: "Mäßiger, örtlich auflebender Südwind, stark föhnbeeinflusst.", signals: [.warning]),
                    DayForecast(date: day(2), headline: "Wechselhaft und windig",
                                details: ["TREND: Meist wechselhaft mit einzelnen Schauern, sehr windig."],
                                wind: "Sehr starker WNW-Wind.", isTrend: true, signals: [.disturbed]),
                ]),
                RegionForecast(region: .suedalpen, days: [
                    DayForecast(date: day(0), headline: "Nordföhn, Frontreste im Osten",
                                summary: "Überwiegend freundlich mit Nordföhn.",
                                details: ["Bassano: bei Ostwind evtl. mäßiger Thermiktag."],
                                wind: "Meist Nord bis Nordföhn, am Ostrand starker Ostwind.", signals: [.thermal, .warning]),
                    DayForecast(date: day(1), headline: "Hochdruckeinfluss",
                                summary: "Freundlich mit etwas Ac/Ci.",
                                details: ["Bassano: meist mäßige, teils mäßig-gute Thermik, Basis 1500–1700 m NN."],
                                wind: "Schwacher bis mäßiger SW-Wind.", signals: [.thermal]),
                    DayForecast(date: day(2), headline: "Starker Nordföhn, Front im Osten",
                                details: ["TREND: Nach Westen auflockernd, sonst wechselhaft mit sehr starkem Nordföhn."],
                                wind: "Meist starker Nordföhn.", isTrend: true, signals: [.disturbed, .warning]),
                ]),
            ],
            issuedAt: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now),
            nextUpdateAt: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now),
            fetchedAt: now
        )
    }
}
