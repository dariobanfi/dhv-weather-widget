import DHVKit
import Foundation
import WidgetKit

struct ForecastEntry: TimelineEntry {
    var date: Date
    var forecast: Forecast?
    var error: String?
    var isFromCache = false
    var region: RegionID = .nordalpen

    static func sample(region: RegionID = .nordalpen) -> ForecastEntry {
        ForecastEntry(date: .now, forecast: .sample(), region: region)
    }
}
