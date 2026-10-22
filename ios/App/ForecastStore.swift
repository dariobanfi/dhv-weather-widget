import DHVKit
import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class ForecastStore {
    var forecast: Forecast? = ForecastCache.load()
    var error: String?
    var isFromCache = false
    var isLoading = false
    var selectedRegion: RegionID = .nordalpen

    /// Downloads the page unless the copy we have is younger than `maxAge`.
    func refresh(maxAge: TimeInterval = 0) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let result = await ForecastLoader.load(maxAge: maxAge)
        forecast = result.forecast
        error = result.error
        isFromCache = result.isFromCache
        if result.error == nil {
            // Let the widgets pick up the new forecast right away.
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func open(_ url: URL) {
        guard url.scheme == "dhvweather", url.host == "region",
              let id = RegionID(rawValue: url.lastPathComponent) else { return }
        selectedRegion = id
    }
}
