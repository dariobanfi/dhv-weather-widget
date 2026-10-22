import DHVKit
import SwiftUI
import WidgetKit

// MARK: - Building blocks

/// A tinted Liquid Glass tile. In full colour it uses real glass tinted by the
/// day's rating; on a tinted or clear Home Screen the system recolours
/// everything, so it falls back to a hairline outline and lets the glass
/// container do the work.
struct GlassTile: ViewModifier {
    var tint: Color
    var cornerRadius: CGFloat = 12
    @Environment(\.widgetRenderingMode) private var mode

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if mode == .fullColor {
            content
                .background {
                    shape.fill(LinearGradient(colors: [tint.opacity(0.46), tint.opacity(0.16)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .glassEffect(.regular.tint(tint.opacity(0.18)), in: shape)
                .overlay {
                    // Specular rim: bright top-left edge fading out.
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.06), .white.opacity(0.22)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.8
                    )
                }
        } else {
            content
                .background { shape.fill(.white.opacity(0.08)) }
                .overlay { shape.strokeBorder(.white.opacity(0.28), lineWidth: 0.6) }
        }
    }
}

extension View {
    func glassTile(_ tint: Color, cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassTile(tint: tint, cornerRadius: cornerRadius))
    }
}

struct RatingIcon: View {
    var day: DayForecast
    var size: CGFloat
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        Image(systemName: day.rating.symbol)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(mode == .fullColor ? .multicolor : .monochrome)
            .widgetAccentable()
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
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let forecast = entry.forecast, !forecast.upcomingDates(from: entry.date).isEmpty {
                grid(forecast)
            } else {
                EmptyState(entry: entry)
            }
        }
        .containerBackground(for: .widget) { SkyBackground() }
        .widgetURL(URL(string: "dhvweather://"))
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
                        Color.clear
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
                                Text("—")
                                    .font(.caption2)
                                    .opacity(0.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .glassTile(.white.opacity(0.3), cornerRadius: isLarge ? 14 : 10)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(isLarge ? 14 : 10)
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
        HStack(alignment: .top, spacing: 3) {
            RatingIcon(day: day, size: 10)
            Text(day.headline)
                .font(.system(size: 9.5, weight: .semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            if day.hasWarning { WarningBadge(size: 7).padding(3) }
        }
        .glassTile(day.tint, cornerRadius: 10)
    }
}

struct LargeCell: View {
    var day: DayForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 4) {
                RatingIcon(day: day, size: 12)
                Spacer(minLength: 0)
                if day.hasWarning { WarningBadge(size: 9) }
            }
            Text(day.headline)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let text = day.summary ?? day.details.first {
                Text(text)
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
        .glassTile(day.tint, cornerRadius: 14)
    }
}

// MARK: - Single region

struct RegionView: View {
    var entry: ForecastEntry
    @Environment(\.widgetFamily) private var family

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
            Label("\(entry.region.shortName): \(day.headline)", systemImage: day.rating.symbol)
        } else {
            Label("DHV: no forecast", systemImage: "wind")
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let day = days.first {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: day.rating.symbol)
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
                        RatingIcon(day: today, size: 13)
                        Text(DayLabel.text(for: today.date, now: entry.date))
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.85)
                        Spacer(minLength: 0)
                        if today.hasWarning { WarningBadge(size: 9) }
                    }
                    Text(today.headline)
                        .font(.system(size: 12.5, weight: .bold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .glassTile(today.tint, cornerRadius: 16)

                ForEach(days.dropFirst().prefix(2)) { day in
                    HStack(spacing: 4) {
                        RatingIcon(day: day, size: 9)
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
