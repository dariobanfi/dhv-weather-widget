import SwiftUI
import WidgetKit

@main
struct DHVWidgetBundle: WidgetBundle {
    var body: some Widget {
        OverviewWidget()
        RegionWidget()
    }
}

struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DHVOverview", provider: OverviewProvider()) { entry in
            OverviewView(entry: entry)
        }
        .configurationDisplayName("DHV Wetter")
        .description("Deutschland, Nordalpen and Südalpen for the next days.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct RegionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DHVRegion", intent: RegionIntent.self, provider: RegionProvider()) { entry in
            RegionView(entry: entry)
        }
        .configurationDisplayName("DHV Region")
        .description("One region at a glance. Long-press the widget to pick the region.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

#Preview("Medium", as: .systemMedium) {
    OverviewWidget()
} timeline: {
    ForecastEntry.sample()
}

#Preview("Large", as: .systemLarge) {
    OverviewWidget()
} timeline: {
    ForecastEntry.sample()
}
