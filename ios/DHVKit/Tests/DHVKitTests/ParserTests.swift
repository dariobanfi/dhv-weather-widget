import XCTest
@testable import DHVKit

final class ParserTests: XCTestCase {
    let cal = Calendar.dhv

    func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testParsesAllRegionsWithTheirOwnDayCounts() throws {
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("legacy-paragraphs"))
        XCTAssertEqual(f.regions.map(\.region), [.deutschland, .nordalpen, .suedalpen])
        XCTAssertEqual(f.regions.map(\.days.count), [2, 3, 3])
        XCTAssertEqual(f.issuedAt, date(2026, 10, 22, 7))
        XCTAssertEqual(f.nextUpdateAt, date(2026, 10, 22, 18))
    }

    func testDayContent() throws {
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("legacy-paragraphs"))
        let de = try XCTUnwrap(f.region(.deutschland))
        XCTAssertEqual(de.days[0].date, date(2026, 10, 22))
        XCTAssertEqual(de.days[0].headline, "Durchwachsen, zunehmend sehr windig")
        XCTAssertEqual(de.days[0].summary, "Anfangs etwas aufgelockert, dann aus Westen stark bewölkt, sehr windig und etwas Regen.")
        XCTAssertEqual(de.days[0].wind, "Zunehmend starker SW-Wind.")
        XCTAssertEqual(de.days[1].headline, "Sturmtief aus Westen") // &nbsp; after the colon
        XCTAssertEqual(de.days[1].summary, "Meist stark bewölkt, regnerisch und sehr windig. Nur ganz im Süden etwas aufgelockert.")

        let sued = try XCTUnwrap(f.region(.suedalpen))
        XCTAssertEqual(sued.days[0].summary, "Überwiegend freundlich mit Nordföhn. SLO noch bewölkt.")
        XCTAssertEqual(sued.days[0].details, ["Bassano: Wenn Schauer ausbleiben, evtl. mäßiger Thermiktag mit Ostwind."])
        XCTAssertTrue(sued.days[2].isTrend)
    }

    func testSignalsAreAggregatedNotOverwritten() throws {
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("legacy-paragraphs"))
        let nord = try XCTUnwrap(f.region(.nordalpen))
        // thumbs-up paragraph followed by an exclamation paragraph: the old
        // Android code kept only the last class and lost the thermal rating.
        XCTAssertEqual(nord.days[0].rating, .good)
        XCTAssertTrue(nord.days[0].hasWarning)
        XCTAssertEqual(nord.days[1].rating, .neutral)
        XCTAssertEqual(nord.days[2].rating, .poor)
        XCTAssertFalse(nord.days[2].hasWarning)
    }

    func testFallbackWithoutAccordionAndYearRollover() throws {
        let f = try DHVParser(now: date(2025, 12, 29, 19)).parse(html: fixture("no-accordion"))
        XCTAssertEqual(f.regions.count, 1)
        let nord = try XCTUnwrap(f.region(.nordalpen))
        XCTAssertEqual(nord.days.map(\.date), [date(2025, 12, 30), date(2025, 12, 31), date(2026, 1, 1)])
        XCTAssertEqual(nord.days[1].wind, "schwach.")
        XCTAssertEqual(f.issuedAt, date(2025, 12, 29, 18))
    }

    func testEmptyPageThrows() {
        XCTAssertThrowsError(try DHVParser().parse(html: "<html><body><p>Wartung</p></body></html>")) { error in
            XCTAssertEqual(error as? DHVError, .noForecastFound)
        }
    }

    func testLabelsFollowTheRealDate() throws {
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("legacy-paragraphs"))
        // Evening of the 22nd, then after midnight: "Today" must move on.
        let evening = date(2026, 10, 22, 21)
        XCTAssertEqual(f.upcomingDates(from: evening).map { DayLabel.text(for: $0, now: evening) },
                       ["Today", "Tomorrow", "Saturday"])
        let nextMorning = date(2026, 10, 23, 6)
        XCTAssertEqual(f.upcomingDates(from: nextMorning).map { DayLabel.text(for: $0, now: nextMorning) },
                       ["Today", "Tomorrow"])
        // Deutschland has no Saturday: the column is matched by date and stays empty.
        XCTAssertNil(f.region(.deutschland)?.day(on: date(2026, 10, 24)))
    }

    func testNextRefreshFollowsDHVSchedule() {
        let now = date(2026, 10, 22, 9)
        var f = Forecast.sample(now: now)
        f.nextUpdateAt = date(2026, 10, 22, 18)
        XCTAssertEqual(ForecastLoader.nextRefresh(after: f, now: now, failed: false), date(2026, 10, 22, 12))
        let afternoon = date(2026, 10, 22, 17)
        XCTAssertEqual(ForecastLoader.nextRefresh(after: f, now: afternoon, failed: false), date(2026, 10, 22, 18, 45))
        XCTAssertEqual(ForecastLoader.nextRefresh(after: f, now: now, failed: true), date(2026, 10, 22, 9, 30))
    }

    // MARK: - Live markup (22.10.2026)

    func live() throws -> Forecast {
        try DHVParser(now: date(2026, 10, 22, 16, 30)).parse(html: fixture("dhv-wetter-2026-10-22"))
    }

    func testLiveStandAndNextUpdate() throws {
        let f = try live()
        XCTAssertEqual(f.issuedAt, date(2026, 10, 22, 16))
        XCTAssertEqual(f.nextUpdateAt, date(2026, 10, 23, 8))
        XCTAssertEqual(f.regions.map(\.region), [.nordalpen, .suedalpen])
        XCTAssertEqual(f.regions.map(\.days.count), [4, 4])
    }

    func testLiveDaySplitsSummaryNotesAndWind() throws {
        let nord = try XCTUnwrap(try live().region(.nordalpen))
        let fr = nord.days[0]
        XCTAssertEqual(fr.headline, "Föhnig, nächste Front im Westen")
        XCTAssertEqual(fr.summary, "Mit vielen As/Ci-Feldern föhnig +/- aufgelockert, nachmittags ganz im Westen zunehmend stark bewölkt, abends/nachts regnerischer Frontdurchgang.")
        XCTAssertEqual(fr.emphasis, ["Mit vielen As/Ci-Feldern föhnig +/- aufgelockert"])
        XCTAssertEqual(fr.wind, "Meist deutlich auflebender Süd- bis WSW-Wind, föhnig.")
        XCTAssertEqual(fr.details, [])
        XCTAssertEqual(fr.sky, .foehn)
        XCTAssertEqual(nord.days[1].sky, .showers)
        XCTAssertEqual(nord.days[2].sky, .rain)
        XCTAssertTrue(nord.days[2].isStormy)
        XCTAssertEqual(nord.days[3].sky, .partlyCloudy)

        let sued = try XCTUnwrap(try live().region(.suedalpen))
        XCTAssertEqual(sued.days[0].details, ["Bassano: Im Tagesverlauf zunehmend wolkig, daher eher mäßige Thermik/Basishöhe. Nachmittags aufkommende Abschattungen."])
        XCTAssertEqual(sued.days[2].wind, "Meist mäßiger SW-Wind, inneralpin oberhalb 2200mNN zunehmend auflebender Westwind.")
    }

    func testLiveTrendAndMidWordBold() throws {
        let sued = try XCTUnwrap(try live().region(.suedalpen))
        let sa = sued.days[1]
        XCTAssertTrue(sa.isTrend)
        XCTAssertEqual(sa.summary?.hasPrefix("Richtung Westen mit Nordföhn aufgelockert, sonst wechselnd"), true)
        XCTAssertEqual(sa.emphasis, ["sonst wechselnd bewölkt mit Nordföhn. In SLO (evtl. auch bis Bassano) noch stark bewölkt, ostwindig und regnerisch"])
        XCTAssertEqual(sa.details.first?.hasPrefix("Bassano: --."), true)
        let mo = sued.days[3]
        XCTAssertTrue(mo.isTrend)
        XCTAssertEqual(mo.summary, "Meist freundlich.")
        XCTAssertEqual(mo.sky, .sunny)
        XCTAssertFalse(sued.days[0].isTrend)
    }

    func testLegendMarkersDoNotLeakIntoDays() throws {
        let f = try live()
        XCTAssertTrue(f.regions.flatMap(\.days).allSatisfy { $0.signals.isEmpty && $0.rating == .neutral })
    }

    func testEveningUpdateStartsTomorrow() throws {
        // After the 16:00 update the page no longer lists Thursday: the first
        // column must read "Tomorrow", not "Today" as the Android widget showed.
        let f = try live()
        let now = date(2026, 10, 22, 17)
        XCTAssertEqual(f.upcomingDates(from: now).map { DayLabel.text(for: $0, now: now) }, ["Tomorrow", "Saturday", "Sunday"])
    }
}
