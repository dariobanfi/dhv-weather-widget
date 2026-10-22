import DHVKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: ForecastStore
    @Environment(\.colorScheme) private var scheme
    @Namespace private var glass

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    regionPicker
                    statusLine
                    if let region = store.forecast?.region(store.selectedRegion) {
                        let days = region.upcomingDays(from: .now)
                        if days.isEmpty {
                            message("No upcoming days for \(region.region.name) in the last download.", symbol: "calendar.badge.exclamationmark")
                        }
                        ForEach(days) { day in
                            DayCard(day: day)
                        }
                    } else if store.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        message(store.error ?? "No forecast yet.", symbol: "wifi.exclamationmark")
                    }
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .animation(.smooth, value: store.selectedRegion)
            }
            .refreshable { await store.refresh() }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("DHV Wetter")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        if store.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Refresh")
                }
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
    }

    // MARK: - Pieces

    private var regionPicker: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(RegionID.allCases) { region in
                    let selected = region == store.selectedRegion
                    let tint = store.forecast?.region(region)?.upcomingDays(from: .now).first?.tint ?? .white
                    Button {
                        store.selectedRegion = region
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tint)
                                .frame(width: 7, height: 7)
                            Text(region.name)
                                .font(.subheadline.weight(selected ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(selected ? .regular.tint(.white.opacity(0.25)).interactive() : .regular.interactive(),
                                 in: .capsule)
                    .glassEffectID(region, in: glass)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let forecast = store.forecast {
            HStack(spacing: 6) {
                if store.isFromCache {
                    Image(systemName: "icloud.slash")
                }
                if let stand = forecast.standText() {
                    Text(stand)
                }
                if let next = forecast.nextUpdateAt, next > .now {
                    Text("· next \(next, format: .dateTime.hour().minute())")
                }
                Spacer()
            }
            .font(.footnote.weight(.medium))
            .opacity(0.8)
        }
    }

    private func message(_ text: String, symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.largeTitle)
            Text(text).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Link(destination: DHVClient.pageURL) {
                Label("Open dhv.de", systemImage: "safari")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glass)

            Text("Forecast by the Deutscher Hängegleiterverband (dhv.de). Not an official flight weather briefing: the pilot decides.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

// MARK: - Day card

struct DayCard: View {
    var day: DayForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DayLabel.text(for: day.date, now: .now))
                        .font(.title3.weight(.bold))
                    Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE")))
                        .font(.caption)
                        .opacity(0.75)
                }
                Spacer()
                HStack(spacing: 6) {
                    if day.isTrend {
                        Text("TREND")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular, in: .capsule)
                    }
                    if day.rating != .neutral {
                        Label(day.rating.label, systemImage: day.rating.symbol)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassEffect(.regular.tint(day.tint.opacity(0.55)), in: .capsule)
                    }
                    Image(systemName: day.sky.symbol)
                        .font(.title)
                        .symbolRenderingMode(.multicolor)
                }
            }

            Text(day.headline)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let summary = day.summary {
                Text(Self.highlighted(summary, emphasis: day.emphasis))
                    .font(.body)
            }
            ForEach(day.details, id: \.self) { detail in
                Text(detail)
                    .font(.callout)
                    .opacity(0.9)
            }

            if day.wind != nil || day.hasWarning {
                VStack(alignment: .leading, spacing: 6) {
                    if let wind = day.wind {
                        Label(wind, systemImage: "wind")
                    }
                    if day.hasWarning {
                        Label("DHV warning for this day", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.warning)
                    }
                }
                .font(.callout.weight(.medium))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(day.tint.opacity(0.22)), in: .rect(cornerRadius: 30))
    }

    /// The summary with DHV's bold key phrases kept bold.
    static func highlighted(_ text: String, emphasis: [String]) -> AttributedString {
        var result = AttributedString(text)
        for phrase in emphasis {
            if let range = result.range(of: phrase) {
                result[range].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        return result
    }
}

// MARK: - Background

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: dark ? [
                Color(red: 0.04, green: 0.07, blue: 0.18), Color(red: 0.08, green: 0.12, blue: 0.28), Color(red: 0.16, green: 0.14, blue: 0.32),
                Color(red: 0.06, green: 0.13, blue: 0.30), Color(red: 0.12, green: 0.22, blue: 0.42), Color(red: 0.24, green: 0.20, blue: 0.40),
                Color(red: 0.05, green: 0.10, blue: 0.20), Color(red: 0.10, green: 0.18, blue: 0.30), Color(red: 0.20, green: 0.16, blue: 0.30),
            ] : [
                Color(red: 0.13, green: 0.38, blue: 0.85), Color(red: 0.25, green: 0.52, blue: 0.95), Color(red: 0.52, green: 0.70, blue: 1.00),
                Color(red: 0.20, green: 0.48, blue: 0.90), Color(red: 0.42, green: 0.66, blue: 0.98), Color(red: 0.98, green: 0.78, blue: 0.62),
                Color(red: 0.30, green: 0.58, blue: 0.92), Color(red: 0.55, green: 0.76, blue: 0.98), Color(red: 0.98, green: 0.86, blue: 0.74),
            ]
        )
        .ignoresSafeArea()
    }
}

#Preview {
    let store = ForecastStore()
    store.forecast = .sample()
    return ContentView(store: store)
}
