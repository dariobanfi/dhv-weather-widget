import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct DHVClient: Sendable {
    public static let pageURL = URL(string: "https://www.dhv.de/wetter/dhv-wetter/")!

    public var url: URL
    public var timeout: TimeInterval

    public init(url: URL = DHVClient.pageURL, timeout: TimeInterval = 20) {
        self.url = url
        self.timeout = timeout
    }

    public func fetch(now: Date = .now) async throws -> Forecast {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("DHVWeather-iOS/1.0 (+https://github.com/dariobanfi/dhv-weather-widget)", forHTTPHeaderField: "User-Agent")
        request.setValue("de-DE,de;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DHVError.badResponse(http.statusCode)
        }
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return try DHVParser(now: now).parse(html: html)
    }
}

/// Last good forecast on disk. Uses the shared App Group container when the
/// app is signed with one, otherwise each process keeps its own copy (the
/// widget then simply fetches for itself).
public enum ForecastCache {
    public static let appGroup = "group.com.dariobanfi.dhvweather"

    static var fileURL: URL? {
        let fm = FileManager.default
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else { return nil }
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("dhv-forecast.json")
    }

    public static func load() -> Forecast? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Forecast.self, from: data)
    }

    public static func save(_ forecast: Forecast) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(forecast).write(to: url, options: .atomic)
    }
}

/// Fetch with cache fallback, shared by the app and the widget.
public enum ForecastLoader {
    public struct Result: Sendable {
        public var forecast: Forecast?
        public var error: String?
        /// True when `forecast` came from the cache because the fetch failed.
        public var isFromCache: Bool
    }

    /// Re-downloads unless the cached copy is younger than `maxAge`.
    public static func load(maxAge: TimeInterval = 0, now: Date = .now) async -> Result {
        let cached = ForecastCache.load()
        if let cached, now.timeIntervalSince(cached.fetchedAt) < maxAge {
            return Result(forecast: cached, error: nil, isFromCache: false)
        }
        do {
            let fresh = try await DHVClient().fetch(now: now)
            ForecastCache.save(fresh)
            return Result(forecast: fresh, error: nil, isFromCache: false)
        } catch {
            return Result(forecast: cached, error: error.localizedDescription, isFromCache: cached != nil)
        }
    }

    /// When the widget should ask again: shortly after DHV's announced next
    /// update (morning ~7–8 h, evening ~18–19 h), and at least every 3 hours.
    public static func nextRefresh(after forecast: Forecast?, now: Date = .now, failed: Bool) -> Date {
        if failed { return now.addingTimeInterval(30 * 60) }
        let cap = now.addingTimeInterval(3 * 3600)
        if let next = forecast?.nextUpdateAt?.addingTimeInterval(45 * 60), next > now {
            return min(next, cap)
        }
        return cap
    }
}
