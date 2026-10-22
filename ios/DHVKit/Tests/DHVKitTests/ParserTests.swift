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
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("dhv-wetter"))
        XCTAssertEqual(f.regions.map(\.region), [.deutschland, .nordalpen, .suedalpen])
        XCTAssertEqual(f.regions.map(\.days.count), [2, 3, 3])
        XCTAssertEqual(f.issuedAt, date(2026, 10, 22, 7))
        XCTAssertEqual(f.nextUpdateAt, date(2026, 10, 22, 18))
    }

    func testDayContent() throws {
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("dhv-wetter"))
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
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("dhv-wetter"))
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
        let f = try DHVParser(now: date(2026, 10, 22, 9)).parse(html: fixture("dhv-wetter"))
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
}
