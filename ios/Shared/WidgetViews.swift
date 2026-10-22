import DHVKit
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Building blocks

/// A day tile: a plain grouping shape whose corners follow the widget's own
/// (about 26 pt on iPhone) minus the content margin.
///
/// Apple's widget guidance leaves the glass to the system: on a Clear or
/// Tinted Home Screen iOS renders the widget in accented mode, removes the
/// container background, draws Liquid Glass or the tint behind the content
/// and turns every colour white. To keep DHV's rating readable there:
/// - the rating colour is drawn as an image marked
///   `widgetAccentedRenderingMode(.fullColor)`, the documented way to keep an
///   image's colour in accented mode (checked on the simulator's Home Screen:
///   green, yellow and red survive in Clear and Tinted, a plain fill doesn't);
/// - good days are drawn a little stronger and each rated day carries its
///   symbol, so the rating still reads if a future iOS whitens images too.
struct DayTile: ViewModifier {
    /// DHV's rating, or nil for an empty slot.
    var rating: Rating?
    var emphasis: Double = 1
    @Environment(\.widgetRenderingMode) private var mode
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background {
            // Same radius for every tile: a concentric shape would square off
            // the inner tiles of the grid.
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            if mode != .fullColor, let rating, rating != .neutral {
                Swatch.image(rating.tint)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .opacity(accentedStrength(rating) * emphasis)
                    .clipShape(shape)
            } else {
                shape.fill(fill.opacity(emphasis))
            }
        }
    }

    private var fill: Color {
        guard mode == .fullColor else { return .white.opacity(0.10) }
        if let rating, rating != .neutral { return rating.tint.opacity(scheme == .dark ? 0.42 : 0.48) }
        return .white.opacity(scheme == .dark ? 0.10 : 0.17)
    }

    private func accentedStrength(_ rating: Rating) -> Double {
        switch rating {
        case .good: 0.62
        case .mixed: 0.58
        case .poor: 0.55
        case .neutral: 0.10
        }
    }
}

/// A solid colour as a bitmap. Unlike a fill, an image can opt out of the
/// accented whitening with `widgetAccentedRenderingMode(.fullColor)`.
enum Swatch {
    static func image(_ color: Color) -> Image {
        let size = CGSize(width: 4, height: 4)
        let bitmap = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(color).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return Image(uiImage: bitmap)
    }
}

extension View {
    func dayTile(_ day: DayForecast?, emphasis: Double = 1) -> some View {
        modifier(DayTile(rating: day?.rating, emphasis: emphasis))
    }
}

/// Sky icon from DHV's wording, in full colour where the Home Screen allows it.
struct SkyIcon: View {
    var day: DayForecast
    var size: CGFloat
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        Image(systemName: day.sky.symbol)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(mode == .fullColor ? .multicolor : .monochrome)
            .widgetAccentable()
    }
}

/// DHV's thumbs marker and warning, if the day has any.
struct DayBadges: View {
    var day: DayForecast
    var size: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            if day.rating != .neutral {
                Image(systemName: day.rating.symbol)
                    .font(.system(size: size, weight: .bold))
                    .widgetAccentable()
            }
            if day.hasWarning { WarningBadge(size: size) }
        }
    }
}

struct WarningBadge: View {
    var size: CGFloat
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(mode == .fullColor ? Palette.warning : .primary)
            .widgetAccentable()
    }
}

struct SkyBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Palette.sky(scheme)
            // Soft sun glow, top right.
            RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.10 : 0.28), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 220)
        }
    }
}

struct EmptyState: View {
    var entry: ForecastEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3)
                .widgetAccentable()
            Text("No DHV forecast yet")
                .font(.caption.weight(.semibold))
            if let error = entry.error {
                Text(error)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .opacity(0.75)
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}

private func regionURL(_ region: RegionID) -> URL? {
    URL(string: "dhvweather://region/\(region.rawValue)")
}

// MARK: - Overview (all regions)

struct OverviewView: View {
    var entry: ForecastEntry
    /// Set only when the view is drawn outside WidgetKit (screenshot gallery).
    var familyOverride: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    var body: some View {
        content
        .containerBackground(for: .widget) { SkyBackground() }
        .widgetURL(URL(string: "dhvweather://"))
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if let forecast = entry.forecast, !forecast.upcomingDates(from: entry.date).isEmpty {
                grid(forecast)
            } else {
                EmptyState(entry: entry)
            }
        }
    }

    private var isLarge: Bool { family == .systemLarge }

    private func grid(_ forecast: Forecast) -> some View {
        let dates = forecast.upcomingDates(from: entry.date)
        let labelWidth: CGFloat = isLarge ? 40 : 30
        let spacing: CGFloat = isLarge ? 8 : 5

        return VStack(alignment: .leading, spacing: spacing) {
            if isLarge {
                HStack(alignment: .firstTextBaseline) {
                    Label("DHV Wetter", systemImage: "wind")
                        .font(.subheadline.weight(.bold))
                        .widgetAccentable()
                    Spacer()
                    statusText(forecast)
                }
            }
            HStack(spacing: spacing) {
                Group {
                    if isLarge {
                        // Fixed height: a bare Color.clear would claim a share of the rows' space.
                        Color.clear.frame(height: 1)
                    } else {
                        Image(systemName: entry.isFromCache ? "icloud.slash" : "wind")
                            .font(.system(size: 11, weight: .bold))
                            .widgetAccentable()
                    }
                }
                .frame(width: labelWidth, alignment: .leading)
                ForEach(dates, id: \.self) { date in
                    Text(DayLabel.text(for: date, now: entry.date, short: !isLarge))
                        .font(.system(size: isLarge ? 12 : 10.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .widgetAccentable()
                }
            }
            ForEach(forecast.regions) { region in
                HStack(spacing: spacing) {
                    Text(isLarge ? region.region.shortName : String(region.region.shortName.prefix(1)))
                        .font(.system(size: isLarge ? 12 : 13, weight: .heavy, design: .rounded))
                        .frame(width: labelWidth, alignment: .leading)
                        .widgetAccentable()
                    ForEach(dates, id: \.self) { date in
                        Group {
                            if let day = region.day(on: date) {
                                if isLarge { LargeCell(day: day) } else { MediumCell(day: day) }
                            } else {
                                // No forecast for this region on that day: a fainter, empty tile.
                                Text("—")
                                    .font(.caption2)
                                    .opacity(0.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .dayTile(nil, emphasis: 0.5)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(isLarge ? 14 : 11)
    }

    private func statusText(_ forecast: Forecast) -> some View {
        HStack(spacing: 3) {
            if entry.isFromCache { Image(systemName: "icloud.slash") }
            if let stand = forecast.standText() { Text(stand) }
        }
        .font(.caption2.weight(.medium))
        .opacity(0.8)
    }
}

struct MediumCell: View {
    var day: DayForecast

    var body: some View {
        // Icons on their own row, so the badges never sit on the text.
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                SkyIcon(day: day, size: 10)
                Spacer(minLength: 0)
                DayBadges(day: day, size: 10)
            }
            Text(day.headline)
                .font(.system(size: 9.5, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dayTile(day)
    }
}

struct LargeCell: View {
    var day: DayForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 4) {
                SkyIcon(day: day, size: 12)
                Spacer(minLength: 0)
                DayBadges(day: day, size: 11)
            }
            Text(day.headline)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if !day.emphasis.isEmpty || day.summary != nil {
                Text(day.emphasis.isEmpty ? (day.summary ?? "") : day.keyPhrase)
                    .font(.system(size: 9.5))
                    .lineLimit(3)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            if let wind = day.wind {
                Label {
                    Text(wind).lineLimit(2)
                } icon: {
                    Image(systemName: "wind").widgetAccentable()
                }
                .font(.system(size: 8.5, weight: .medium))
                .opacity(0.85)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dayTile(day)
    }
}

// MARK: - Single region

struct RegionView: View {
    var entry: ForecastEntry
    /// Set only when the view is drawn outside WidgetKit (screenshot gallery).
    var familyOverride: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    private var days: [DayForecast] {
        entry.forecast?.region(entry.region)?.upcomingDays(from: entry.date) ?? []
    }

    var body: some View {
        content
            .widgetURL(regionURL(entry.region))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
                .containerBackground(for: .widget) { Color.clear }
        default:
            small
                .containerBackground(for: .widget) { SkyBackground() }
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let day = days.first {
            Label("\(entry.region.shortName): \(day.headline)", systemImage: day.sky.symbol)
        } else {
            Label("DHV: no forecast", systemImage: "wind")
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let day = days.first {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: day.sky.symbol)
                    Text("\(entry.region.name) · \(DayLabel.text(for: day.date, now: entry.date))")
                        .lineLimit(1)
                    if day.hasWarning { Image(systemName: "exclamationmark.triangle.fill") }
                }
                .font(.caption.weight(.bold))
                .widgetAccentable()
                Text(day.headline)
                    .font(.caption)
                    .lineLimit(2)
                if let next = days.dropFirst().first {
                    Text("\(DayLabel.text(for: next.date, now: entry.date, short: true)): \(next.headline)")
                        .font(.caption2)
                        .lineLimit(1)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label("No DHV forecast", systemImage: "wind")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var small: some View {
        if let today = days.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(entry.region.name)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .widgetAccentable()
                    Spacer(minLength: 0)
                    if entry.isFromCache {
                        Image(systemName: "icloud.slash").font(.caption2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        SkyIcon(day: today, size: 13)
                        Text(DayLabel.text(for: today.date, now: entry.date))
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.85)
                        Spacer(minLength: 0)
                        DayBadges(day: today, size: 11)
                    }
                    Text(today.headline)
                        .font(.system(size: 12.5, weight: .bold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .dayTile(today)

                ForEach(days.dropFirst().prefix(2)) { day in
                    HStack(spacing: 4) {
                        SkyIcon(day: day, size: 9)
                            .frame(width: 13)
                        Text(DayLabel.text(for: day.date, now: entry.date, short: true))
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 28, alignment: .leading)
                        Text(day.headline)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(12)
        } else {
            EmptyState(entry: entry)
        }
    }
}

